import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/logger.dart';
import '../providers/app_settings_provider.dart';
import '../services/app_update_service.dart';
import '../utils/helpers.dart';

class AppUpdateGuard extends StatefulWidget {
  final Widget child;

  const AppUpdateGuard({super.key, required this.child});

  @override
  State<AppUpdateGuard> createState() => _AppUpdateGuardState();
}

class _AppUpdateGuardState extends State<AppUpdateGuard> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final settingsProvider = Provider.of<AppSettingsProvider>(
      context,
      listen: false,
    );

    final prompt = await AppUpdateService.instance.checkForUpdate();
    if (!mounted || prompt == null) return;

    if (!prompt.isForce && !settingsProvider.appSettings.autoUpdate) {
      return;
    }

    await _showUpdateDialog(prompt);
  }

  Future<void> _showUpdateDialog(AppUpdatePrompt prompt) async {
    final info = prompt.info;
    final title = info.title ?? 'تحديث جديد متاح';
    final message =
        info.message ??
        'يتوفر تحديث جديد للتطبيق لتحسين الأداء وإضافة ميزات جديدة.';
    final updateUrl = info.updateUrl.trim();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !prompt.isForce,
      builder: (dialogContext) {
        return PopScope(
          canPop: !prompt.isForce,
          child: AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                Text('الإصدار الحالي: ${prompt.currentVersion}'),
                Text('الإصدار الجديد: ${info.latestVersion}'),
                const SizedBox(height: 12),
                if (updateUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openUpdateUrl(updateUrl),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('فتح رابط التحديث'),
                  )
                else
                  const Text('لم يتم توفير رابط التحديث بعد.'),
              ],
            ),
            actions: [
              if (!prompt.isForce)
                TextButton(
                  onPressed: () async {
                    await AppUpdateService.instance.markDismissed(
                      info.latestVersion,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('لاحقًا'),
                ),
              FilledButton.icon(
                onPressed: updateUrl.isEmpty
                    ? null
                    : () => _openUpdateUrl(updateUrl),
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Text('تحديث الآن'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUpdateUrl(String updateUrl) async {
    try {
      await Helpers.launchURL(updateUrl);
    } catch (e) {
      AppLogger.error('❌ Failed to open update URL', e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحديث')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
