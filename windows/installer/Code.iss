// Pascal Script Core Logic for Ell Tall Market (سوق التل)

// WinAPI declarations for UI animation
function AnimateWindow(hWnd: HWND; dwTime: DWORD; dwFlags: DWORD): Boolean;
external 'AnimateWindow@user32.dll stdcall';

const
  AW_BLEND = $00080000;
  AW_ACTIVATE = $00020000;

// Helper to check VC++ Runtime 2015-2022 x64
function IsVCRedistNeeded: Boolean;
var
  Installed: Cardinal;
begin
  // HKLM key for Visual C++ 2015-2022 Redistributable (x64)
  if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
  begin
    Result := (Installed <> 1);
  end
  else
  begin
    Result := True;
  end;
end;

// Helper to check Internet Connection via OLE WinHttpRequest
function IsInternetConnected: Boolean;
var
  WinHttpReq: Variant;
begin
  Result := True;
  try
    WinHttpReq := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    // Query your website to test actual internet connectivity
    WinHttpReq.Open('GET', 'https://eltal-market.com/', False);
    WinHttpReq.Send('');
  except
    Result := False;
  end;
end;

// Version Comparison Helper
// Returns: 1 if V1 > V2, -1 if V1 < V2, 0 if V1 = V2
function CompareVersion(V1, V2: String): Integer;
var
  P1, P2: Integer;
  Part1, Part2: String;
  Val1, Val2: Integer;
begin
  Result := 0;
  while ((V1 <> '') or (V2 <> '')) and (Result = 0) do
  begin
    P1 := Pos('.', V1);
    if P1 > 0 then
    begin
      Part1 := Copy(V1, 1, P1 - 1);
      V1 := Copy(V1, P1 + 1, Length(V1));
    end
    else
    begin
      Part1 := V1;
      V1 := '';
    end;

    P2 := Pos('.', V2);
    if P2 > 0 then
    begin
      Part2 := Copy(V2, 1, P2 - 1);
      V2 := Copy(V2, P2 + 1, Length(V2));
    end
    else
    begin
      Part2 := V2;
      V2 := '';
    end;

    if Part1 = '' then Val1 := 0 else Val1 := StrToInt(Part1);
    if Part2 = '' then Val2 := 0 else Val2 := StrToInt(Part2);

    if Val1 > Val2 then
      Result := 1
    else if Val1 < Val2 then
      Result := -1;
  end;
end;

// Run Uninstaller Silently
function UninstallOldVersion(UninstallStr: String): Boolean;
var
  ResultCode: Integer;
  UninstallExe: String;
begin
  Result := False;
  UninstallExe := UninstallStr;
  if Copy(UninstallExe, 1, 1) = '"' then
  begin
    UninstallExe := Copy(UninstallExe, 2, Length(UninstallExe) - 2);
  end;
  
  if FileExists(UninstallExe) then
  begin
    if Exec(UninstallExe, '/SILENT /NORESTART /SUPPRESSMSGBBOXES', ExtractFilePath(UninstallExe), SW_SHOW, ewWaitUntilTerminated, ResultCode) then
    begin
      Result := (ResultCode = 0);
    end;
  end;
end;

// Setup Initialization
function InitializeSetup: Boolean;
var
  InstalledVersion: String;
  CurrentVersion: String;
  UninstallPath: String;
begin
  Result := True;
  
  // 1. Force 64-bit check
  if not Is64BitInstallMode then
  begin
    MsgBox('This application requires a 64-bit edition of Windows.', mbCriticalError, MB_OK);
    Result := False;
    Exit;
  end;

  // 2. Warn if Offline
  if not IsInternetConnected then
  begin
    if MsgBox(CustomMessage('InternetRequired') + ' Do you want to continue offline?', mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
      Exit;
    end;
  end;

  // 3. Downgrade protection check
  CurrentVersion := '{#MyAppVersion}';
  if RegQueryStringValue(HKLM, 'Software\{#MyAppPublisher}\{#MyAppName}', 'Version', InstalledVersion) then
  begin
    if CompareVersion(InstalledVersion, CurrentVersion) > 0 then
    begin
      MsgBox(CustomMessage('DowngradeProtect'), mbCriticalError, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  // 4. Automatic Uninstaller trigger for upgrades (Note: Curly braces doubled to prevent Inno constant parsing)
  if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{5D0737C8-D2D4-4822-BDD5-76C8F923DE0F}_is1', 'UninstallString', UninstallPath) then
  begin
    if WizardSilent or (MsgBox(CustomMessage('UninstallOld'), mbConfirmation, MB_YESNO) = IDYES) then
    begin
      if not UninstallOldVersion(UninstallPath) then
      begin
        MsgBox('Uninstall of the previous version failed. Please uninstall it manually before running setup.', mbError, MB_OK);
        Result := False;
        Exit;
      end;
    end;
  end;
end;

// Wizard Form UI customizations
procedure InitializeWizard;
begin
  // Set fonts and brand colors (BGR values: Green #2EAF4A -> $4AAF2E, Blue #1C7ED6 -> $D67E1C)
  WizardForm.Font.Name := 'Segoe UI';
  WizardForm.WelcomeLabel1.Font.Name := 'Segoe UI';
  WizardForm.WelcomeLabel1.Font.Size := 16;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  WizardForm.WelcomeLabel1.Font.Color := $4AAF2E; // Primary Green BGR
  
  WizardForm.WelcomeLabel2.Font.Name := 'Segoe UI';
  
  // Custom White Theme backgrounds
  WizardForm.Color := clWhite;
  WizardForm.WelcomePage.Color := clWhite;
  WizardForm.InnerPage.Color := clWhite;
  WizardForm.FinishedPage.Color := clWhite;
  
  // Header text styling
  WizardForm.PageNameLabel.Font.Name := 'Segoe UI';
  WizardForm.PageNameLabel.Font.Style := [fsBold];
  WizardForm.PageNameLabel.Font.Color := $4AAF2E;
  
  WizardForm.PageDescriptionLabel.Font.Name := 'Segoe UI';
  WizardForm.PageDescriptionLabel.Font.Color := $D67E1C; // Secondary Blue BGR
  
  // Apply fade-in animation to installer window
  AnimateWindow(WizardForm.Handle, 250, AW_ACTIVATE or AW_BLEND);
end;
