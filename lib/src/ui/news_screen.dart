import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Announcements from the operators (newest first) and their links.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen marks everything read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).markNewsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final catalog = state.catalog;
    final posts = catalog.posts;
    final withLinks = catalog.operators.where((o) => o.links.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.newsTitle)),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          children: [
            UpdatedLine(fetchedAt: state.fetchedAt, offline: state.offline),
            if (posts.isEmpty)
              ListTile(leading: const Icon(Icons.inbox_outlined), title: Text(l.newsEmpty)),
            for (final p in posts) _PostCard(post: p),
            if (withLinks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Text(
                  l.linksHeader,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            for (final op in withLinks) ...[
              ListTile(
                leading: OperatorAvatar(operator: op),
                title: Text(op.name.resolve(context.lang)),
              ),
              for (final link in op.links)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 16),
                  leading: Icon(_linkIcon(link.url)),
                  title: Text(link.label.resolve(context.lang)),
                  onTap: () => _open(context, link),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static IconData _linkIcon(String url) {
    if (url.startsWith('tel:')) return Icons.phone_outlined;
    if (url.startsWith('mailto:')) return Icons.mail_outline;
    return Icons.open_in_new;
  }

  Future<void> _open(BuildContext context, OperatorLink link) async {
    final uri = Uri.tryParse(link.url);
    // The server allows only https, mailto and tel; check again here.
    if (uri == null || !{'https', 'mailto', 'tel'}.contains(uri.scheme)) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final p = post;
    final op = state.catalog.operator(p.operatorId);
    final route = p.routeId == null ? null : state.catalog.route(p.routeId!);
    final lang = context.lang;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OperatorAvatar(operator: op, radius: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    op?.name.resolve(lang) ?? '',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (route != null) ...[RouteBadge(route: route), const SizedBox(width: 8)],
                Text(
                  DateFormat.MMMd(lang).add_Hm().format(p.publishedAt.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(p.title.resolve(lang), style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(p.body.resolve(lang)),
            // The operator did not write this post in the reader's language;
            // machine translation is a follow-up.
            if (!p.title.hasLanguage(lang))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.notInYourLanguage, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
