import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import 'widgets.dart';

/// Language names in their own language, so everyone finds theirs.
const _nativeNames = {'ja': '日本語', 'en': 'English', 'de': 'Deutsch'};

String languageName(BuildContext context, String? code) =>
    code == null ? context.l10n.languageFollowPhone : (_nativeNames[code] ?? code);

/// Choose the language: on first start (then continue to joining) or from
/// settings.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, required this.onboarding});

  final bool onboarding;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String? _choice;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _choice = AppScope.read(context).chosenLanguage;
    }
  }

  Future<void> _select(String? code) async {
    setState(() => _choice = code);
    // Applied right away, so the screen switches language as a preview.
    await AppScope.read(context).setLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final options = <String?>[null, ...supportedLanguages];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onboarding ? l.appTitle : l.settingsLanguage),
        automaticallyImplyLeading: !widget.onboarding,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          if (widget.onboarding) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const BrandMark(size: 64),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l.languageTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
          RadioGroup<String?>(
            groupValue: _choice,
            onChanged: _select,
            child: Column(
              children: [
                for (final code in options)
                  RadioListTile<String?>(
                    key: Key('lang-${code ?? 'system'}'),
                    value: code,
                    title: Text(languageName(context, code)),
                  ),
              ],
            ),
          ),
          if (widget.onboarding)
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                key: const Key('language-continue'),
                onPressed: () => AppScope.read(context).finishOnboarding(_choice),
                child: Text(l.continueButton),
              ),
            ),
        ],
      ),
    );
  }
}
