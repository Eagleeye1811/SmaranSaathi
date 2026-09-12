import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/app_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/locale_controller.dart';

/// The language picker.
///
/// Large targets, each showing its language in its own script — someone who
/// cannot read English cannot read the word "Assamese" either. Selecting one
/// rebuilds the app immediately: the patient stays where they are and the
/// screen changes language around them.
///
/// Laid out two-per-row rather than one row of four: at four options, a
/// single row would shrink every tap target and risk wrapping a script-heavy
/// label like "অসমীয়া" — a two-row grid keeps each chip exactly the size the
/// three-language version had, and scales if a fifth language is ever added.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  static const List<_LanguageOption> _languages = <_LanguageOption>[
    _LanguageOption(Locale('en'), 'English'),
    _LanguageOption(Locale('hi'), 'हिन्दी'),
    _LanguageOption(Locale('as'), 'অসমীয়া'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // Without a LocaleScope there is no language to change, so offer nothing
    // rather than a picker whose taps would do nothing. The running app
    // always provides one; bare widget-test harnesses do not.
    final LocaleController? controller = LocaleScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final String current = controller.locale.languageCode;
    final AppState state = AppScope.read(context);

    void select(Locale locale) {
      controller.setLocale(locale);
      // Persisted separately from the live controller (see AppState.localeCode)
      // so the choice survives a restart — LocaleController itself is
      // deliberately not Hive-backed.
      state.localeCode = locale.languageCode;
    }

    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SoftIcon(icon: Icons.translate_rounded, color: AppColors.secondary),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.settingsLanguage, style: AppText.h3),
                    const SizedBox(height: 2),
                    Text(l.settingsLanguageNote, style: AppText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              for (int i = 0; i < _languages.length; i++) ...<Widget>[
                Expanded(
                  child: _LanguageChip(
                    label: _languages[i].native,
                    selected: _languages[i].locale.languageCode == current,
                    onTap: () => select(_languages[i].locale),
                  ),
                ),
                if (i < _languages.length - 1) const SizedBox(width: Insets.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption(this.locale, this.native);
  final Locale locale;

  /// The language's own name, in its own script.
  final String native;
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primaryTint,
          borderRadius: Corners.r(Corners.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.body.wght(700).tint(
                selected ? Colors.white : AppColors.primaryDeep,
              ),
        ),
      ),
    );
  }
}
