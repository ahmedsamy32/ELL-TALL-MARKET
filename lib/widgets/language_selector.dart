import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.locale.languageCode == 'ar';

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(isArabic ? 'اللغة' : 'Language'),
      trailing: Switch(
        value: isArabic,
        onChanged: (value) {
          localeProvider.toggleLocale();
        },
      ),
      subtitle: Text(isArabic ? 'العربية' : 'English'),
    );
  }
}
