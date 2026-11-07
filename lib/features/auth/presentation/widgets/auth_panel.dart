import '../../../../core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/auth_providers.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/app_components.dart';

class AuthPanel extends HookConsumerWidget {
  const AuthPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = useTextEditingController(),
        password = useTextEditingController();
    final register = ref.watch(authModeProvider);
    final action = ref.watch(authActionProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppIconTile(
                    Icons.business_outlined,
                    size: 48,
                    emphasized: true,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  register ? 'Create owner account' : 'Owner sign in',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your business, routes and published bus timetables.',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('auth-email'),
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('auth-password'),
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (action.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      action.error.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: action.isLoading
                      ? null
                      : () => ref
                            .read(authActionProvider.notifier)
                            .submit(
                              email.text,
                              password.text,
                              register: register,
                            ),
                  child: ActionShimmer(
                    loading: action.isLoading,
                    label: register ? 'Create account' : 'Sign in',
                    child: Text(register ? 'Create account' : 'Sign in'),
                  ),
                ),
                TextButton(
                  onPressed: action.isLoading
                      ? null
                      : () => ref.read(authModeProvider.notifier).toggle(),
                  child: Text(
                    register
                        ? 'Already registered? Sign in'
                        : 'New owner? Create account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
