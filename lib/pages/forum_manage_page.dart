import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/forum_site.dart';
import '../config/site_context.dart';
import '../l10n/s.dart';
import '../navigation/nav_action_bus.dart';
import '../services/forum_switch_service.dart';

/// Manage the forum list and switch the active forum.
///
/// Forum switching is intentionally immediate: [ForumSwitchService] advances
/// the session generation, reloads the site-scoped credentials, resets preload
/// state, and refreshes providers before returning to the home destination.
class ForumManagePage extends ConsumerStatefulWidget {
  const ForumManagePage({super.key});

  @override
  ConsumerState<ForumManagePage> createState() => _ForumManagePageState();
}

class _ForumManagePageState extends ConsumerState<ForumManagePage> {
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    SiteContext.instance.addListener(_onSiteChanged);
  }

  @override
  void dispose() {
    SiteContext.instance.removeListener(_onSiteChanged);
    super.dispose();
  }

  void _onSiteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _switchTo(ForumSite site) async {
    if (_switching) return;
    final siteContext = SiteContext.instance;
    if (site.id == siteContext.current.id) return;

    setState(() => _switching = true);
    try {
      await ForumSwitchService.switchTo(
        ProviderScope.containerOf(context),
        site,
      );
      if (!mounted) return;
      ref.requestNavDestination(NavEntryIds.home);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  String _defaultSiteName(String rawUrl) {
    var input = rawUrl.trim();
    if (!input.contains('://')) input = 'https://$input';
    return Uri.tryParse(input)?.host ?? rawUrl.trim();
  }

  Future<void> _addForum() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<({String name, String baseUrl})>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.forum_addAction),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.forum_addNameLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: l10n.forum_siteAddressLabel,
                  hintText: l10n.forum_siteAddressHint,
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isEmpty) return;
                Navigator.of(dialogContext).pop(
                  (
                    name: nameController.text.trim(),
                    baseUrl: url,
                  ),
                );
              },
              child: Text(l10n.forum_addAction),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    urlController.dispose();
    if (result == null || !mounted) return;

    // Adding a forum does not make a network request. The active login WebView
    // will discover an optional hCaptcha key from that forum's own login DOM.
    ForumSite site;
    try {
      site = ForumSite.fromBaseUrl(
        name: result.name.isNotEmpty
            ? result.name
            : _defaultSiteName(result.baseUrl),
        baseUrl: result.baseUrl,
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.common_checkInput)),
      );
      return;
    }

    await SiteContext.instance.addSite(site);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.forum_addSuccess(site.name))),
    );
    setState(() {});
  }

  Future<void> _removeForum(ForumSite site) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.forum_deleteTitle),
        content: Text(l10n.forum_deleteMessage(site.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await SiteContext.instance.removeSite(site.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.forum_deleteFailed)),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final siteContext = SiteContext.instance;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final allSites = siteContext.allSites;
    final current = siteContext.current;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forum_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            l10n.forum_current(current.name),
            style: theme.textTheme.titleMedium,
          ),
          Text(current.baseUrl, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          ...allSites.map(
            (site) => Card(
              child: ListTile(
                leading: Icon(
                  site.isPreset
                      ? Icons.public_rounded
                      : Icons.forum_rounded,
                ),
                title: Text(site.name),
                subtitle: Text(site.baseUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (site.id == current.id)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      )
                    else if (_switching)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.subdirectory_arrow_left_rounded,
                        ),
                        tooltip: l10n.forum_switchTo,
                        onPressed: () => _switchTo(site),
                      ),
                    if (!site.isPreset)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: l10n.common_delete,
                        onPressed: () => _removeForum(site),
                      ),
                  ],
                ),
                onTap: site.id == current.id ? null : () => _switchTo(site),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addForum,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.forum_addAction),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.forum_description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
