; 巧克力音乐 Windows 安装包脚本（Inno Setup 6.3+）
;
; 用法：
;   1. 先构建 release 产物：flutter build windows --release
;   2. 用 Inno Setup 编译本脚本：ISCC.exe windows\installer\chocolate_music.iss
;   3. 产物在 dist\chocolate_music-<版本>-setup.exe
;
; 安装位置默认在 %LOCALAPPDATA%\Programs\ChocolateMusic（每用户安装，不弹 UAC）。
; 这一点是刻意的：应用默认把下载目录解析成「可执行文件同级的 Music 文件夹」
; （见 lib/MusicManagement.dart 的 defaultDownloadDir），装到 Program Files 会
; 因为没写权限而建不出目录。

#define AppName "巧克力音乐"
#define AppNameEn "Chocolate Music"
#define AppVersion "1.0.3"
#define AppPublisher "com.xjh.chocolatemusic"
#define AppExeName "chocolate_music.exe"
; release 产物目录，相对本脚本所在位置
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8F3A5C21-6D4E-4B7A-9C15-2E8B7D4F1A63}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\ChocolateMusic
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; 每用户安装，不需要管理员权限
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
OutputDir=..\..\dist
OutputBaseFilename=chocolate_music-{#AppVersion}-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
; 覆盖安装时自动关闭正在运行的旧版本
CloseApplications=yes

[Languages]
; Inno Setup 只自带英文，简体中文（ChineseSimplified.isl）属于非官方翻译、不随安装包分发。
; 想让安装向导也是中文的话，把这个文件放进 Inno Setup 的 Languages 目录后取消下面一行注释：
;   https://github.com/jrsoftware/issrc/blob/main/Files/Languages/ChineseSimplified.isl
; Name: "chinese"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"

[Files]
; 整个 release 目录。要排除三类东西：
;   *.lib / *.exp              链接期产物，运行时用不到
;   data\*.json / *.db         应用运行时写在 <exe>\data\ 下的用户状态
;                              （见 lib/FileManage.dart、lib/MusicManagement.dart），
;                              开发机跑过一次就会留下，不能打进安装包
;   Music\*                    默认下载目录，里面是用户下载的歌
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; \
    Excludes: "*.lib,*.exp,accountData.json,setting.json,playback-state.json,recommendListDate.json,musicLibrary.db,Music\*"

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即运行 {#AppName}"; Flags: nowait postinstall skipifsilent
