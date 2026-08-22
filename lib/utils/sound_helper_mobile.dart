import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void requestNotificationPermissions() {
  // Mobile/Desktop permission handling
}

void playNotificationSound() {
  if (!kIsWeb && Platform.isWindows) {
    _playWindowsSound();
  } else {
    SystemSound.play(SystemSoundType.click);
  }
}

void showPlatformDesktopNotification({required String title, required String body}) {
  if (!kIsWeb && Platform.isWindows) {
    _showWindowsToast(title, body);
  }
}

void _playWindowsSound() {
  try {
    Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '[System.Media.SystemSounds]::Exclamation.Play(); [System.Media.SystemSounds]::Asterisk.Play()'
    ]);
  } catch (_) {
    SystemSound.play(SystemSoundType.click);
  }
}

void _showWindowsToast(String title, String body) {
  try {
    final cleanTitle = title.replaceAll("'", "''").replaceAll('\r', '').replaceAll('\n', ' ');
    final cleanBody = body.replaceAll("'", "''").replaceAll('\r', '').replaceAll('\n', ' ');
    
    // PowerShell script using WinRT ToastNotificationManager registered under 'سوق التل'
    final psScript = '''
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    \$toastXml = [xml]\$template.GetXml()
    \$nodes = \$toastXml.GetElementsByTagName("text")
    \$nodes.Item(0).InnerText = '$cleanTitle'
    \$nodes.Item(1).InnerText = '$cleanBody'
    \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    \$xml.LoadXml(\$toastXml.OuterXml)
    \$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('سوق التل').Show(\$toast)
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    \$n = New-Object System.Windows.Forms.NotifyIcon
    \$n.Icon = [System.Drawing.SystemIcons]::Information
    \$n.Visible = \$true
    \$n.ShowBalloonTip(7000, '$cleanTitle', '$cleanBody', [System.Windows.Forms.ToolTipIcon]::Info)
}
[System.Media.SystemSounds]::Exclamation.Play()
''';

    // Encode to UTF-16LE bytes to execute reliably via base64 in PowerShell
    final units = <int>[];
    for (final char in psScript.codeUnits) {
      units.add(char & 0xFF);
      units.add((char >> 8) & 0xFF);
    }
    final encoded = base64.encode(units);
    
    Process.run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded]);
  } catch (_) {}
}
