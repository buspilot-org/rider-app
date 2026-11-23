import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import 'language_screen.dart';
import 'widgets.dart';

const sourceCodeUrl = 'https://github.com/buspilot-org/rider-app';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final catalog = state.catalog;
    final members = catalog.memberOperatorIds;
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.settingsLanguage),
            subtitle: Text(languageName(context, state.chosenLanguage)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanguageScreen(onboarding: false)),
            ),
          ),
          header(l.settingsOperators),
          if (members.isEmpty)
            ListTile(title: Text(l.homeEmptyTitle)),
          for (final op in catalog.operators.where((o) => members.contains(o.id)))
            ListTile(
              leading: OperatorAvatar(operator: op),
              title: Text(op.name.resolve(context.lang)),
              trailing: TextButton(
                onPressed: () => _leave(context, op.id, op.name.resolve(context.lang)),
                child: Text(l.leave),
              ),
            ),
          header(l.settingsPrivacy),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.privacyText),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
            title: Text(l.deleteData, style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _delete(context),
          ),
          header(l.settingsAbout),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l.sourceCode),
            subtitle: const Text(sourceCodeUrl),
            onTap: () => launchUrl(Uri.parse(sourceCodeUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.licenses),
            onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _leave(BuildContext context, String operatorId, String name) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.leaveConfirmTitle(name)),
        content: Text(l.leaveConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.leave)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AppScope.read(context).leaveOperator(operatorId);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    try {
      await AppScope.read(context).deleteMyData();
      navigator.popUntil((r) => r.isFirst);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
