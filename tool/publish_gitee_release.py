#!/usr/bin/env python3
"""把 dist/ 下的发布产物传到 Gitee Releases。

    GITEE_TOKEN=<你的私人令牌> python tool/publish_gitee_release.py

令牌从环境变量读，不走命令行参数，避免留在 shell 历史里。
在 gitee.com → 设置 → 私人令牌 新建，只需要 projects 权限。

脚本是幂等的：标签对应的 Release 已存在就复用，同名附件已传过就跳过。
"""

import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

OWNER = "xjhwht"
REPO = "chocolate-music_-flutter"
TAG = "v1.0.2"
RELEASE_NAME = "巧克力音乐 v1.0.2"
NOTES = "docs/releases/v1.0.2.md"
ASSETS = [
    "dist/chocolate_music-1.0.2-setup.exe",
    "dist/chocolate_music-portable.exe",
    "dist/chocolate_music-1.0.2-windows-x64.zip",
]

API = "https://gitee.com/api/v5"


def call(method, path, token, params=None, body=None):
    url = "%s%s" % (API, path)
    # GET 的令牌走查询串（POST 是放在 body 里，见下面两处调用）
    query = dict(params or {})
    if method == "GET":
        query["access_token"] = token
    if query:
        url += "?" + urllib.parse.urlencode(query)
    data = None
    headers = {"Accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        raise RuntimeError("HTTP %d %s -> %s" % (e.code, path, detail[:300]))


def upload_asset(release_id, token, path):
    """multipart/form-data 上传单个附件。"""
    boundary = "----gitee" + uuid.uuid4().hex
    name = os.path.basename(path)
    ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"

    parts = []
    for field, value in (("access_token", token),):
        parts.append(
            ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
             % (boundary, field, value)).encode("utf-8")
        )
    parts.append(
        ("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n"
         "Content-Type: %s\r\n\r\n" % (boundary, name, ctype)).encode("utf-8")
    )
    with open(path, "rb") as f:
        parts.append(f.read())
    parts.append(("\r\n--%s--\r\n" % boundary).encode("utf-8"))
    payload = b"".join(parts)

    url = "%s/repos/%s/%s/releases/%d/attach_files" % (API, OWNER, REPO, release_id)
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "multipart/form-data; boundary=%s" % boundary,
            "Content-Length": str(len(payload)),
            "Accept": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=1800) as r:
        return json.loads(r.read().decode("utf-8") or "null")


def load_env(path=".env"):
    """把 .env 里的键值对读进环境变量。已存在的环境变量优先，不覆盖。"""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


def main():
    load_env()
    token = os.environ.get("GITEE_TOKEN", "").strip()
    if not token:
        print("请先设置环境变量 GITEE_TOKEN，或在项目根目录的 .env 里写一行 GITEE_TOKEN=<令牌>", file=sys.stderr)
        return 1

    missing = [p for p in ASSETS if not os.path.exists(p)]
    if missing:
        print("找不到产物：%s" % ", ".join(missing), file=sys.stderr)
        return 1

    body = ""
    if os.path.exists(NOTES):
        with open(NOTES, encoding="utf-8") as f:
            body = f.read()

    print("==> 查找标签 %s 对应的 Release" % TAG)
    releases = call("GET", "/repos/%s/%s/releases" % (OWNER, REPO), token)
    release = None
    for r in releases or []:
        if r.get("tag_name") == TAG:
            release = r
            break

    if release:
        print("    已存在，复用 id=%s" % release.get("id"))
    else:
        print("    未找到，创建新 Release")
        release = call(
            "POST",
            "/repos/%s/%s/releases" % (OWNER, REPO),
            token,
            body={
                "access_token": token,
                "tag_name": TAG,
                "name": RELEASE_NAME,
                "body": body,
                "target_commitish": "main",
                "prerelease": False,
            },
        )
        print("    创建成功 id=%s" % release.get("id"))

    release_id = release.get("id") or release.get("release_id")
    if not release_id:
        print("拿不到 release id：%s" % json.dumps(release, ensure_ascii=False)[:300], file=sys.stderr)
        return 1

    existing = {a.get("name") for a in (release.get("assets") or [])}
    for path in ASSETS:
        name = os.path.basename(path)
        size_mb = os.path.getsize(path) / 1048576.0
        if name in existing:
            print("==> %s 已存在，跳过" % name)
            continue
        print("==> 上传 %s（%.1f MB）" % (name, size_mb))
        upload_asset(release_id, token, path)
        print("    完成")

    print()
    print("完成：https://gitee.com/%s/%s/releases/tag/%s" % (OWNER, REPO, TAG))
    return 0


if __name__ == "__main__":
    sys.exit(main())
