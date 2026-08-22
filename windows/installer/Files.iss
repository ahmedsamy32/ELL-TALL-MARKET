; Files configuration for Ell Tall Market (سوق التل)

[Files]
; Main Executable
Source: "..\..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All other DLLs, assets and subfolders (data folder)
Source: "..\..\build\windows\x64\runner\Release\*"; Excludes: "*.exe"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Resource Documentation
Source: "Resources\License.txt"; DestDir: "{app}\Docs"; Flags: ignoreversion
Source: "Resources\Readme.txt"; DestDir: "{app}\Docs"; Flags: ignoreversion
Source: "Resources\Changelog.txt"; DestDir: "{app}\Docs"; Flags: ignoreversion

; VC++ Redistributable 2015-2022 Installer (Preprocessor Check)
#ifexist "Resources\VC_redist.x64.exe"
Source: "Resources\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: IsVCRedistNeeded
#endif
