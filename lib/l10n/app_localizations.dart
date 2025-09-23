import 'package:flutter/material.dart';
import 'package:ell_tall_market/generated/l10n/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
