// 巧克力音乐 单文件绿色版启动器
//
// 把整个 release 目录以 zip 形式内嵌在本 exe 里（资源名 payload.zip）。运行时：
//   1. 在 exe 同级目录下的 chocolate_music\ 里解压出应用
//   2. 启动 chocolate_music.exe，并把命令行参数原样透传
//
// 之所以解压到同级目录而不是 %TEMP%，是因为应用默认把下载目录解析成
// 「可执行文件同级的 Music 文件夹」（见 lib/MusicManagement.dart 的
// defaultDownloadDir）。解压到临时目录的话，临时目录一被清理下载的歌就没了。
// 同级目录不可写时（只读介质等）才退回到 %LOCALAPPDATA%\ChocolateMusic。
//
// 编译见 tool/build_portable_exe.ps1。为兼容系统自带的 .NET Framework 编译器，
// 这里只用 C# 5 语法。

using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

internal static class Launcher
{
    const string PayloadResource = "payload.zip";
    const string AppFolderName = "chocolate_music";
    const string AppExeName = "chocolate_music.exe";
    const string MarkerName = ".payload.sha256";

    [STAThread]
    static int Main(string[] args)
    {
        try
        {
            Assembly self = Assembly.GetExecutingAssembly();
            string exePath = self.Location;
            string baseDir = Path.GetDirectoryName(exePath);

            using (Stream payload = self.GetManifestResourceStream(PayloadResource))
            {
                if (payload == null)
                {
                    Fail("内置的应用数据缺失，这个 exe 可能没有打包完整。");
                    return 1;
                }

                string hash = Sha256Hex(payload);

                // 优先就地解压，保持绿色版「所有东西都在 exe 旁边」的语义
                string target = Path.Combine(baseDir, AppFolderName);
                string error;
                if (!EnsureExtracted(payload, target, hash, out error))
                {
                    // 只读介质 / Program Files 之类写不进去，退到用户目录
                    string fallback = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "ChocolateMusic");
                    if (!EnsureExtracted(payload, fallback, hash, out error))
                    {
                        Fail("应用解压失败。\r\n\r\n" + target + "\r\n" + fallback + "\r\n\r\n" + error);
                        return 1;
                    }
                    target = fallback;
                }

                string appExe = Path.Combine(target, AppExeName);
                if (!File.Exists(appExe))
                {
                    Fail("解压完成，但找不到主程序：\r\n" + appExe);
                    return 1;
                }

                ProcessStartInfo psi = new ProcessStartInfo(appExe);
                psi.WorkingDirectory = target;
                psi.UseShellExecute = false;
                psi.Arguments = JoinArguments(args);

                Process.Start(psi);
                return 0;
            }
        }
        catch (Exception ex)
        {
            Fail("启动失败：\r\n" + ex.Message);
            return 1;
        }
    }

    /// <summary>
    /// 确保 target 里是当前这版应用。已是最新则直接返回；否则解压覆盖。
    /// 覆盖而不是先删目录，是为了不误删用户下载在 Music\ 里的歌。
    /// </summary>
    static bool EnsureExtracted(Stream payload, string target, string hash, out string error)
    {
        error = null;

        string marker = Path.Combine(target, MarkerName);
        if (IsUpToDate(marker, hash) && File.Exists(Path.Combine(target, AppExeName)))
        {
            return true;
        }

        try
        {
            payload.Position = 0;
            Directory.CreateDirectory(target);

            string root = Path.GetFullPath(target);
            using (ZipArchive zip = new ZipArchive(payload, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in zip.Entries)
                {
                    // Compress-Archive 写出来的条目用反斜杠分隔、目录条目也带尾分隔符，
                    // 这里统一成正斜杠再判断，否则目录条目会被当成文件去建 FileStream。
                    string rel = entry.FullName.Replace('\\', '/').TrimStart('/');
                    if (rel.Length == 0)
                    {
                        continue;
                    }

                    if (rel.EndsWith("/", StringComparison.Ordinal))
                    {
                        Directory.CreateDirectory(Path.Combine(target, rel));
                        continue;
                    }

                    string dest = Path.GetFullPath(Path.Combine(target, rel));

                    // zip slip 防护：条目名里带 ..\ 时不能写到 target 外面去
                    if (!dest.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    string parent = Path.GetDirectoryName(dest);
                    if (!string.IsNullOrEmpty(parent))
                    {
                        Directory.CreateDirectory(parent);
                    }

                    // 用 Open() 而不是 ExtractToFile()，少依赖一个程序集
                    using (Stream src = entry.Open())
                    using (FileStream dst = new FileStream(dest, FileMode.Create, FileAccess.Write, FileShare.None))
                    {
                        src.CopyTo(dst);
                    }
                }
            }

            File.WriteAllText(marker, hash, Encoding.ASCII);
            return true;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            return false;
        }
    }

    static bool IsUpToDate(string marker, string hash)
    {
        try
        {
            return File.Exists(marker) && File.ReadAllText(marker).Trim() == hash;
        }
        catch (Exception)
        {
            return false;
        }
    }

    static string Sha256Hex(Stream s)
    {
        s.Position = 0;
        using (SHA256 sha = SHA256.Create())
        {
            byte[] digest = sha.ComputeHash(s);
            StringBuilder sb = new StringBuilder(digest.Length * 2);
            foreach (byte b in digest)
            {
                sb.Append(b.ToString("x2"));
            }
            return sb.ToString();
        }
    }

    /// <summary>按 Windows 命令行规则给参数加引号，保证原样透传给应用。</summary>
    static string JoinArguments(string[] args)
    {
        StringBuilder sb = new StringBuilder();
        foreach (string a in args)
        {
            if (sb.Length > 0)
            {
                sb.Append(' ');
            }
            sb.Append(QuoteArgument(a));
        }
        return sb.ToString();
    }

    static string QuoteArgument(string s)
    {
        if (s.Length > 0 && s.IndexOfAny(new char[] { ' ', '\t', '"', '\\' }) < 0)
        {
            return s;
        }

        StringBuilder sb = new StringBuilder();
        sb.Append('"');
        int backslashes = 0;
        foreach (char c in s)
        {
            if (c == '\\')
            {
                backslashes++;
                sb.Append(c);
            }
            else if (c == '"')
            {
                sb.Append('\\', backslashes + 1);
                sb.Append('"');
                backslashes = 0;
            }
            else
            {
                backslashes = 0;
                sb.Append(c);
            }
        }
        sb.Append('\\', backslashes);
        sb.Append('"');
        return sb.ToString();
    }

    static void Fail(string message)
    {
        MessageBox.Show(message, "巧克力音乐", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
