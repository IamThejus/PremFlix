; Inno Setup script for the PremFlix Windows installer.
;
; Builds a classic single-file installer (premflix-<version>-setup.exe)
; from the release runner output. Reuses `flutter build windows --release`
; — no second compile. Pass the version via /DAppVersion=<version>.
;
; Usage:
;   flutter build windows --release
;   iscc /DAppVersion=1.0.0 windows\packaging\premflix.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "PremFlix"
#define AppPublisher "PremFlix"
#define AppExeName "premflix.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B6C6E2B0-6C6A-4E2E-9C0B-9A5E6B6B2A31}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=..\..\dist
OutputBaseFilename=premflix-{#AppVersion}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\runner\resources\app_icon.ico
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
