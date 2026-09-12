import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/locale_controller.dart';

/// Compact language selector button placed in the top-right of role pages.
///
/// Displays a globe icon with the currently active language name (English,
/// हिंदी, or অসমীয়া). When tapped, opens a modal sheet displaying the three
/// supported languages with clear visual indication of the current selection.
/// Selecting an option immediately switches the whole UI in place and persists
/// the selection.
class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({
    super.key,
    this.color,
  });

  final Color? color;

  /// The app's languages, each written in its own script. Public so the
  /// inline `LanguageSelector` shows exactly the same names — two controls
  /// spelling a language differently is the kind of detail that makes a
  /// person doubt they picked the right one.
  static const List<({String code, String name, String englishName})> languages =
      <({String code, String name, String englishName})>[
    (code: 'en', name: 'English', englishName: 'English'),
    (code: 'hi', name: 'हिंदी', englishName: 'Hindi'),
    (code: 'as', name: 'অসমীয়া', englishName: 'Assamese'),
  ];

  static String _labelFor(String code) => switch (code) {
        'hi' => 'हिंदी',
        'as' => 'অসমীয়া',
        _ => 'English',
      };

  @override
  Widget build(BuildContext context) {
    final LocaleController? controller = LocaleScope.maybeOf(context);
    final String currentCode = controller?.locale.languageCode ??
        Localizations.maybeLocaleOf(context)?.languageCode ??
        'en';
    final Color effectiveColor = color ?? AppColors.inkSoft;
    final Color textColor = color ?? AppColors.ink;

    return Pressable(
      onTap: () => _openSheet(context, currentCode),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: effectiveColor.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.language_rounded, size: 14, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              _labelFor(currentCode),
              style: AppText.caption.wght(700).sized(11.5).tint(textColor),
            ),
            const SizedBox(width: 1),
            Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: effectiveColor),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, String currentCode) {
    final AppLocalizations l = AppLocalizations.of(context);
    final LocaleController? controller = LocaleScope.maybeOf(context);
    final AppState state = AppScope.read(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: AppColors.softShadow(y: 8, blur: 28, opacity: 0.12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.settingsLanguage,
                            style: AppText.h3.wght(800),
                          ),
                        ),
                        RoundIconButton(
                          icon: Icons.close_rounded,
                          size: 32,
                          tooltip: l.actionClose,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final ({String code, String englishName, String name}) item in languages) ...<Widget>[
                      _LanguageTile(
                        name: item.name,
                        englishName: item.englishName,
                        selected: currentCode == item.code,
                        onTap: () {
                          controller?.setLocale(Locale(item.code));
                          state.localeCode = item.code;
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      if (item != languages.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.name,
    required this.englishName,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String englishName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint.withValues(alpha: 0.65) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    style: AppText.body
                        .wght(selected ? 800 : 600)
                        .tint(selected ? AppColors.primaryDeep : AppColors.ink),
                  ),
                  if (englishName != name) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      englishName,
                      style: AppText.caption.tint(AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.hairline, size: 22),
          ],
        ),
      ),
    );
  }
}
