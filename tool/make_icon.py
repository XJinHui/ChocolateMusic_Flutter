#!/usr/bin/env python3
"""把一张 PNG 转成 Windows 图标（.ico）。

    python tool/make_icon.py assets/images/app_icon.png windows/runner/resources/app_icon.ico

为什么不直接用 Pillow 的 `Image.save(..., format='ICO')`：它会把所有尺寸都存成
PNG 压缩条目。Windows 的惯例（Flutter 模板自带的 app_icon.ico 也是这么做的）是
小尺寸用 BMP/DIB、只有 256x256 用 PNG —— 资源管理器图标缓存、任务管理器这些
shell 组件对小尺寸 PNG 条目的支持并不可靠，会出现图标不更新的现象。

所以这里手写 ICO：16/24/32/48/64/128 走 32bpp BGRA 的 BMP 条目，
256x256 走 PNG 条目。
"""

import struct
import sys

from PIL import Image

# 用 BMP 条目的尺寸；256 单独走 PNG
BMP_SIZES = [16, 24, 32, 48, 64, 128]
PNG_SIZES = [256]


def bmp_entry(img):
    """把一个 RGBA 图编码成 ICO 里的 BMP(DIB) 条目。"""
    w, h = img.size
    px = img.load()

    # XOR 位图：32bpp BGRA，自下而上逐行
    xor = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            xor += bytes((b, g, r, a))

    # AND 掩码：1bpp，每行按 4 字节对齐，同样自下而上。
    # 32bpp 下 Windows 以 alpha 为准，掩码只是兼容旧版，全透明像素置 1。
    row_bytes = ((w + 31) // 32) * 4
    and_mask = bytearray()
    for y in range(h - 1, -1, -1):
        row = bytearray(row_bytes)
        for x in range(w):
            if px[x, y][3] == 0:
                row[x // 8] |= 0x80 >> (x % 8)
        and_mask += row

    # BITMAPINFOHEADER：高度写两倍，因为后面跟着 XOR 图和 AND 掩码
    header = struct.pack(
        "<IiiHHIIiiII",
        40,          # biSize
        w,           # biWidth
        h * 2,       # biHeight
        1,           # biPlanes
        32,          # biBitCount
        0,           # biCompression = BI_RGB
        len(xor),    # biSizeImage
        0, 0, 0, 0,  # 分辨率 / 调色板 / 重要色数
    )
    return header + bytes(xor) + bytes(and_mask)


def png_entry(img):
    """把一个 RGBA 图编码成 ICO 里的 PNG 条目。"""
    import io

    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def build(src_path, dst_path):
    src = Image.open(src_path).convert("RGBA")

    entries = []
    for size in BMP_SIZES:
        if size > src.width:
            continue
        entries.append((size, bmp_entry(src.resize((size, size), Image.LANCZOS))))
    for size in PNG_SIZES:
        if size > src.width:
            continue
        entries.append((size, png_entry(src.resize((size, size), Image.LANCZOS))))

    # ICONDIR + 每个条目的 ICONDIRENTRY，图像数据紧随其后
    offset = 6 + 16 * len(entries)
    header = struct.pack("<HHH", 0, 1, len(entries))
    dirs = bytearray()
    blob = bytearray()

    for size, data in entries:
        # 256 在单字节字段里记作 0
        dim = 0 if size >= 256 else size
        dirs += struct.pack(
            "<BBBBHHII",
            dim, dim, 0, 0, 1, 32, len(data), offset,
        )
        blob += data
        offset += len(data)

    with open(dst_path, "wb") as f:
        f.write(header + bytes(dirs) + bytes(blob))

    return entries


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1

    entries = build(sys.argv[1], sys.argv[2])
    print("已生成 %s" % sys.argv[2])
    for size, data in entries:
        print("  %3dx%-3d %6d bytes  %s" % (size, size, len(data),
                                            "PNG" if data[:8] == b"\x89PNG\r\n\x1a\n" else "BMP"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
