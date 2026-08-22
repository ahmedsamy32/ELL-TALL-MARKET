; Main Inno Setup Script for Ell Tall Market (سوق التل)
; Enterprise-Grade Modular Installer configuration

#define MyAppName "سوق التل"
#define MyAppEnglishName "Ell Tall Market"
#define MyAppVersion "1.1.8"
#define MyAppPublisher "El Tal Market"
#define MyAppExeName "ell_tall_market.exe"
#define MyProjectRoot "..\.."

[Setup]
; Unique application GUID
AppId={{5D0737C8-D2D4-4822-BDD5-76C8F923DE0F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://eltal-market.com/
AppSupportURL=https://eltal-market.com/
AppUpdatesURL=https://eltal-market.com/
DefaultDirName={autopf}\{#MyAppEnglishName}
DisableProgramGroupPage=yes

; 64-bit Restriction and Architecture setup
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0

; Privileges Requirement
PrivilegesRequired=admin

; App Mutex for update closing detection
AppMutex=EllTallMarketMutex
CloseApplications=yes

; Compiler Output settings
OutputDir={#MyProjectRoot}\build\windows\installer
OutputBaseFilename=سوق التل
SetupIconFile=Images\Logo.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression parameters (Maximum/Ultra Compression)
Compression=lzma2/ultra64
LZMAUseSeparateProcess=yes
LZMADictionarySize=65536
LZMANumBlockThreads=4
SolidCompression=yes

; User Interface Styling
WizardStyle=modern
WizardImageFile=Images\WizardImage.bmp
WizardSmallImageFile=Images\WizardSmall.bmp

; Wizard pages resources
LicenseFile=Resources\License.txt
InfoBeforeFile=Resources\Readme.txt
InfoAfterFile=Resources\Changelog.txt

; Include Modular Installer sections
#include "Languages.iss"
#include "Tasks.iss"
#include "Files.iss"
#include "Registry.iss"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Option to launch program or VC++ runtime installation from Files.iss checks
#ifexist "Resources\VC_redist.x64.exe"
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "{cm:VCRuntimeInstall}"; Flags: runhidden; Check: IsVCRedistNeeded
#endif
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; Tasks: not startupicon
Filename: "https://eltal-market.com/"; Description: "{cm:VisitWebsite}"; Flags: postinstall shellexec skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
#include "Code.iss"
