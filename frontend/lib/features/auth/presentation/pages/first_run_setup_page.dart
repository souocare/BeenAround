import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../application/first_run_setup_cubit.dart';
import '../../application/first_run_setup_state.dart';
import '../../data/first_run_setup_repository.dart';

class FirstRunSetupPage extends StatefulWidget {
  const FirstRunSetupPage({required this.onCompleted, super.key});

  final VoidCallback onCompleted;

  @override
  State<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends State<FirstRunSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<FirstRunSetupCubit>().submit(
      displayName: _displayNameController.text,
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocConsumer<FirstRunSetupCubit, FirstRunSetupState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase &&
          current.phase == FirstRunSetupPhase.success,
      listener: (context, state) => widget.onCompleted(),
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
                          size: 72,
                          color: colors.primary,
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'BeenAround',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          'Welcome to BeenAround',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Create your administrator account to get started.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 36),

                        _field(
                          context,
                          label: 'DISPLAY NAME',
                          controller: _displayNameController,
                          icon: Icons.badge_outlined,
                          validator: (value) {
                            final error = _required(value);

                            if (error != null) {
                              return error;
                            }

                            if (value!.trim().length > 100) {
                              return 'Maximum 100 characters.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _field(
                          context,
                          label: 'USERNAME',
                          controller: _usernameController,
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (!RegExp(
                              r'^[a-z0-9_]{3,32}$',
                            ).hasMatch(value!.trim().toLowerCase())) {
                              return 'Use 3–32 letters, numbers or underscores.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _field(
                          context,
                          label: 'EMAIL (OPTIONAL)',
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return null;
                            }

                            if (email.length > 320 ||
                                !RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email)) {
                              return 'Enter a valid email address.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _field(
                          context,
                          label: 'PASSWORD',
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          obscureText: !_showPassword,
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
                          validator: (value) {
                            if (value == null || value.length < 12) {
                              return 'Use at least 12 characters.';
                            }

                            if (value.length > 1024) {
                              return 'Maximum 1024 characters.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _field(
                          context,
                          label: 'CONFIRM PASSWORD',
                          controller: _confirmPasswordController,
                          icon: Icons.lock_reset_outlined,
                          obscureText: !_showConfirmPassword,
                          suffix: IconButton(
                            tooltip: 'Toggle confirmation visibility',
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match.';
                            }

                            return null;
                          },
                        ),

                        if (state.phase == FirstRunSetupPhase.failure) ...[
                          const SizedBox(height: 20),
                          _errorMessage(context, state.failure),
                        ],

                        const SizedBox(height: 30),

                        SizedBox(
                          height: 52,
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
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Create Administrator Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        Text(
                          'Self-hosted. Your data stays yours.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
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

  Widget _field(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }

  Widget _errorMessage(BuildContext context, FirstRunSetupFailure? failure) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final message = switch (failure) {
      FirstRunSetupFailure.alreadyCompleted =>
        'Initial setup has already been completed.',
      FirstRunSetupFailure.validation =>
        'Please review the information entered.',
      FirstRunSetupFailure.unavailable =>
        'Unable to reach the server. Please try again.',
      FirstRunSetupFailure.unexpected ||
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
