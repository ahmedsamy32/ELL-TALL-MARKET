import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = localeProvider.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.settings),
        ),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(isArabic ? 'العربية' : 'English'),
              trailing: Switch(
                value: isArabic,
                onChanged: (value) {
                  localeProvider.toggleLocale();
                },
              ),
            ),
            // يمكن إضافة المزيد من إعدادات التطبيق هنا
          ],
        ),
      ),
    );
  }
}
