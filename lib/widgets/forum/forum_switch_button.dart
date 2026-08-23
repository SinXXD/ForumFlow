import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/site_context.dart';
import '../../l10n/s.dart';
import '../../navigation/nav_action_bus.dart';
import '../../pages/forum_manage_page.dart';
import '../../services/forum_switch_service.dart';

/// AppBar shortcut for switching forums.
///
/// It remains visible for guest users so browsing another preset forum does
/// not require signing in first.
class ForumSwitchButton extends ConsumerWidget {
  const ForumSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteContext = SiteContext.instance;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: siteContext,
      builder: (context, _) {
        final current = siteContext.current;
        final currentName =
            current.displayName(context.l10n.forum_defaultName);
        return Tooltip(
          message: context.l10n.forum_switchTooltip(currentName),
          child: IconButton(
            onPressed: () => _showSwitcher(context, ref),
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.public_rounded, size: 18),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    currentName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSwitcher(BuildContext context, WidgetRef ref) async {
    final siteContext = SiteContext.instance;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.forum_switchTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final site in siteContext.allSites)
                ListTile(
                  leading: Icon(
                    site.isPreset
                        ? Icons.public_rounded
                        : Icons.forum_rounded,
                  ),
                  title: Text(
                    site.displayName(l10n.forum_defaultName),
                  ),
                  subtitle: Text(site.baseUrl),
                  trailing: site.id == siteContext.current.id
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, site.id),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.forum_manageAction),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ForumManagePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
    if (selectedId == null || !context.mounted) return;

    final site = siteContext.siteById(selectedId);
    if (site == null || site.id == siteContext.current.id) return;
    await ForumSwitchService.switchTo(
      ProviderScope.containerOf(context),
      site,
    );
    if (!context.mounted) return;
    ref.requestNavDestination(NavEntryIds.home);
  }
}
