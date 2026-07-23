import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/repositories/auth_repository.dart';
import '../../../../core/services/device_identity_service.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../../../core/services/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/entrance_reveal.dart';
import '../../../../core/widgets/premflix_wordmark.dart';
import '../../../../core/widgets/user_avatar.dart';

/// App settings: accent theme, account, storage, about.
///
/// The accent picker applies instantly — the whole app restyles the
/// moment a swatch is tapped, which doubles as the theme preview.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final identity = ref.watch(deviceIdentityProvider);
    final theme = Theme.of(context);
    final inset = context.pageInset;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(inset, 8, inset, 48),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Text('Settings', style: theme.textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 24),
            const EntranceReveal(
              child: _Section(
                title: 'Appearance',
                child: _AccentPicker(),
              ),
            ),
            if (session != null) ...[
              const SizedBox(height: 28),
              EntranceReveal(
                delay: const Duration(milliseconds: 70),
                child: _Section(
                  title: 'Account',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          UserAvatar(session: session, size: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.userName,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  session.serverUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SettingsAction(
                        icon: Icons.logout_rounded,
                        label: 'Sign out',
                        destructive: true,
                        onTap: () async {
                          await ref
                              .read(authRepositoryProvider)
                              .logout(session);
                          await ref
                              .read(sessionControllerProvider.notifier)
                              .clear();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            EntranceReveal(
              delay: const Duration(milliseconds: 140),
              child: _Section(
                title: 'Storage',
                child: Column(
                  children: [
                    _SettingsAction(
                      icon: Icons.image_outlined,
                      label: 'Clear image cache',
                      onTap: () async {
                        await DefaultCacheManager().emptyCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Image cache cleared')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _SettingsAction(
                      icon: Icons.storage_rounded,
                      label: 'Clear library cache',
                      onTap: () async {
                        await ref.read(mediaCacheProvider).clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Library cache cleared')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            EntranceReveal(
              delay: const Duration(milliseconds: 210),
              child: _Section(
                title: 'About',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremFlixWordmark(fontSize: 26, animated: false),
                    const SizedBox(height: 10),
                    Text(
                      'A cinematic Jellyfin client.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Version ${identity.appVersion} · '
                      'Device: ${identity.deviceName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded card section with a header.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall!
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Accent swatch row; the selected preset shows a ring and check.
class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(themeControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accent color',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final preset in AccentPreset.values)
              _AccentSwatch(
                preset: preset,
                selected: preset == active,
                onTap: () => ref
                    .read(themeControllerProvider.notifier)
                    .setAccent(preset),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          active.label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AccentSwatch extends StatefulWidget {
  const _AccentSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AccentSwatch> createState() => _AccentSwatchState();
}

class _AccentSwatchState extends State<_AccentSwatch> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.preset.label,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered || widget.selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.preset.gradient,
                border: Border.all(
                  color:
                      widget.selected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  if (widget.selected || _hovered)
                    BoxShadow(
                      color: widget.preset.color.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                ],
              ),
              child: widget.selected
                  ? const Icon(Icons.check_rounded,
                      size: 22, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable row action inside a section card.
class _SettingsAction extends StatefulWidget {
  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool destructive;

  @override
  State<_SettingsAction> createState() => _SettingsActionState();
}

class _SettingsActionState extends State<_SettingsAction> {
  bool _hovered = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.destructive ? AppColors.error : AppColors.text;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onTap();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.cardHighlight
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Icon(widget.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
