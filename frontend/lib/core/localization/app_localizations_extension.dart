import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this) ?? AppLocalizationsEn();
}
