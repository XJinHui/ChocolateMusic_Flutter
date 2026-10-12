# 构建单文件绿色版 exe。
#
#   powershell -ExecutionPolicy Bypass -File tool\build_portable_exe.ps1
#
# 依赖 tool\build_windows_release.ps1 先跑出 dist\chocolate_music-<版本>-windows-x64.zip，
# 这里把那个 zip 作为内嵌资源塞进启动器，产出一个双击即用的 exe：
#   dist\chocolate_music-portable.exe
#
# 启动器源码见 tool\portable_launcher\Launcher.cs。
# 用系统自带的 .NET Framework 编译器（csc.exe）编译，不需要装 .NET SDK。

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml 里找不到 version 字段' }
$version = $versionLine.Matches[0].Groups[1].Value.Trim().Split('+')[0]

$payload = "dist\chocolate_music-$version-windows-x64.zip"
if (-not (Test-Path $payload)) {
    throw "找不到 $payload，请先运行 tool\build_windows_release.ps1"
}

# 系统自带的 C# 编译器，64 位机器上用 Framework64 那份
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "找不到 csc.exe：$csc" }

$out = 'dist\chocolate_music-portable.exe'
$icon = 'windows\runner\resources\app_icon.ico'
$source = 'tool\portable_launcher\Launcher.cs'

Write-Host "==> 编译启动器，内嵌 $payload"
# -codepage:65001 是因为 Launcher.cs 是 UTF-8 无 BOM，里面有中文字符串
& $csc -nologo -target:winexe -platform:anycpu -codepage:65001 -optimize+ `
    "-win32icon:$icon" `
    "-resource:$payload,payload.zip" `
    -r:System.IO.Compression.dll -r:System.IO.Compression.FileSystem.dll -r:System.Windows.Forms.dll `
    "-out:$out" `
    $source
if ($LASTEXITCODE -ne 0) { throw 'csc 编译失败' }

$sizeMB = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host ''
Write-Host "完成：$out（$sizeMB MB）"
