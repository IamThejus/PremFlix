import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/router/route_args.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/accent_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/entrance_reveal.dart';
import '../../../../core/widgets/ghost_button.dart';
import '../../../../core/widgets/premflix_wordmark.dart';
import '../controllers/login_controller.dart';

/// Server sign-in screen.
///
/// Two modes, driven by [LoginArgs]:
///  * **server known** (chosen on the discovery screen) — the address
///    field is replaced by a compact server header; the user only enters
///    credentials, and can fall back to manual entry via "Use a different
///    server".
///  * **manual** — the editable address field is shown, so hand-typed and
///    remote servers work exactly as before.
///
/// On success no navigation happens here — establishing the session flips
/// the router to the home shell.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.args = const LoginArgs()});

  final LoginArgs args;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // In server-known mode the address is fixed; the field is hidden but
    // the controller still carries the value into submit().
    if (widget.args.serverUrl != null) {
      _serverController.text = widget.args.serverUrl!;
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(loginControllerProvider.notifier).submit(
          serverUrl: _serverController.text,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);
    final submitting = loginState.isLoading;
    final error = loginState.whenOrNull(
      error: (e, _) => e is ApiException ? e.message : e.toString(),
    );

    final hasServer = widget.args.hasServer;
    final subtitle = hasServer
        ? 'Sign in to ${widget.args.serverName ?? 'your server'}'
        : 'Sign in to your Jellyfin server';

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pageInset,
              vertical: 48,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EntranceReveal(
                      child: Center(child: PremFlixWordmark(fontSize: 36)),
                    ),
                    const SizedBox(height: 12),
                    EntranceReveal(
                      delay: const Duration(milliseconds: 70),
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 40),
                    EntranceReveal(
                      delay: const Duration(milliseconds: 140),
                      child: hasServer
                          ? _ServerHeader(
                              name: widget.args.serverName ?? 'Jellyfin server',
                              address: widget.args.serverUrl!,
                            )
                          : AppTextField(
                              controller: _serverController,
                              label: 'Server address',
                              hint: 'http://192.168.1.20:8096',
                              icon: Icons.dns_outlined,
                              keyboardType: TextInputType.url,
                              autofillHints: const [AutofillHints.url],
                              textInputAction: TextInputAction.next,
                              enabled: !submitting,
                              autofocus: true,
                            ),
                    ),
                    const SizedBox(height: 20),
                    EntranceReveal(
                      delay: const Duration(milliseconds: 210),
                      child: AppTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_outline,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        enabled: !submitting,
                        autofocus: hasServer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    EntranceReveal(
                      delay: const Duration(milliseconds: 280),
                      child: AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscure: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _submit(),
                        enabled: !submitting,
                      ),
                    ),
                    // Error banner animates open/closed beneath the form.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.error
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.error
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                color: AppColors.text,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),
                    EntranceReveal(
                      delay: const Duration(milliseconds: 350),
                      child: AccentButton(
                        label: 'Sign In',
                        icon: Icons.play_arrow_rounded,
                        loading: submitting,
                        onPressed: _submit,
                      ),
                    ),
                    if (hasServer) ...[
                      const SizedBox(height: 12),
                      EntranceReveal(
                        delay: const Duration(milliseconds: 410),
                        child: GhostButton(
                          label: 'Use a different server',
                          icon: Icons.swap_horiz_rounded,
                          onPressed:
                              submitting ? null : () => context.pop(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only server chip shown in place of the address field once a
/// server has been chosen on the discovery screen.
class _ServerHeader extends StatelessWidget {
  const _ServerHeader({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayAddress = address.replaceFirst(RegExp(r'^https?://'), '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: context.accentGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.dns_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  displayAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 20,
          ),
        ],
      ),
    );
  }
}
