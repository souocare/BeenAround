import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../application/login_cubit.dart';
import '../../application/login_state.dart';
import '../../data/login_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onAuthenticated, super.key});

  final ValueChanged<LoginResult> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<LoginCubit>().submit(
      login: _loginController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocConsumer<LoginCubit, LoginState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase &&
          current.phase == LoginPhase.success,
      listener: (context, state) {
        final result = state.result;

        if (result != null) {
          widget.onAuthenticated(result);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          color: colors.primary,
                          size: 76,
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'BeenAround',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 36),

                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Sign in to continue your travel story.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 40),

                        _buildFieldLabel(context, 'USERNAME OR EMAIL'),

                        const SizedBox(height: AppSpacing.sm),

                        TextFormField(
                          controller: _loginController,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          validator: (value) {
                            final login = value?.trim() ?? '';

                            if (login.isEmpty) {
                              return 'Enter your username or email.';
                            }

                            if (login.length > 320) {
                              return 'Maximum 320 characters.';
                            }

                            return null;
                          },
                          decoration: _decoration(
                            context,
                            icon: Icons.person_outline,
                            hint: 'Username or email',
                          ),
                        ),

                        const SizedBox(height: 22),

                        _buildFieldLabel(context, 'PASSWORD'),

                        const SizedBox(height: AppSpacing.sm),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          onFieldSubmitted: (_) {
                            if (!state.isSubmitting) {
                              _submit();
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password.';
                            }

                            if (value.length > 1024) {
                              return 'Maximum 1024 characters.';
                            }

                            return null;
                          },
                          decoration: _decoration(
                            context,
                            icon: Icons.lock_outline,
                            hint: 'Password',
                            suffix: IconButton(
                              tooltip: 'Toggle password visibility',
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),

                        if (state.phase == LoginPhase.failure) ...[
                          const SizedBox(height: 22),
                          _errorMessage(context, state.failure),
                        ],

                        const SizedBox(height: AppSpacing.xxl),

                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: state.isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            child: state.isSubmitting
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        Text(
                          'Your journeys. Your memories. Your space.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(BuildContext context, String label) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required IconData icon,
    required String hint,
    Widget? suffix,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: colors.onSurfaceVariant),
      suffixIcon: suffix,
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }

  Widget _errorMessage(BuildContext context, LoginFailure? failure) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final message = switch (failure) {
      LoginFailure.invalidCredentials => 'Invalid username/email or password.',
      LoginFailure.unavailable =>
        'Unable to connect to the server. Please try again.',
      LoginFailure.unexpected ||
      null => 'Something went wrong. Please try again.',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onErrorContainer,
          fontSize: 13,
        ),
      ),
    );
  }
}
