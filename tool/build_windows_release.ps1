# 构建 Windows 便携版发布包。
#
#   powershell -ExecutionPolicy Bypass -File tool\build_windows_release.ps1
#
# 产物：
#   dist\chocolate_music\                        可直接运行的目录（双击 chocolate_music.exe）
#   dist\chocolate_music-<版本>-windows-x64.zip  上面的目录打成的便携压缩包
#
# 需要 Flutter 与 Rust 工具链；Rust 侧由 cargokit 在 flutter build 时自动编译。

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# 版本号取自 pubspec.yaml 的 `version:`，形如 1.0.0+1，这里只取前面的语义化版本
$versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml 里找不到 version 字段' }
$version = $versionLine.Matches[0].Groups[1].Value.Trim().Split('+')[0]
Write-Host "版本：$version"

Write-Host '==> flutter build windows --release'
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build 失败' }

$releaseDir = 'build\windows\x64\runner\Release'
$stageDir = "dist\chocolate_music"

# 不该进发布包的东西：
#   *.lib / *.exp   链接期产物，运行时不需要
#   Music           默认下载目录（用户下的歌）
#   data\*.json、data\*.db
#                   应用运行时写在 <exe>\data\ 下的用户状态，见 lib/FileManage.dart
#                   与 lib/MusicManagement.dart。开发机跑过一次就会留下，
#                   复制时不过滤的话会把账号 / 设置一起发出去。
$excludeFiles = @(
    'accountData.json', 'setting.json', 'playback-state.json',
    'recommendListDate.json', 'musicLibrary.db'
)

Write-Host "==> 整理产物到 $stageDir"
if (Test-Path 'dist') { Remove-Item 'dist' -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-Item "$releaseDir\*" $stageDir -Recurse -Force

Get-ChildItem $stageDir -Include '*.lib', '*.exp' -File | Remove-Item -Force
Remove-Item (Join-Path $stageDir 'Music') -Recurse -Force -ErrorAction SilentlyContinue
foreach ($f in $excludeFiles) {
    Remove-Item (Join-Path $stageDir "data\$f") -Force -ErrorAction SilentlyContinue
}

$zipPath = "dist\chocolate_music-$version-windows-x64.zip"
Write-Host "==> 打包 $zipPath"
Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host ''
Write-Host "完成：$zipPath（$sizeMB MB）"
Write-Host "便携版目录：$stageDir"
