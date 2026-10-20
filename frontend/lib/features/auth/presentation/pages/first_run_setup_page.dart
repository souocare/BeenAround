import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  static const _background = Color(0xFF111217);
  static const _fieldBackground = Color(0xFF1B1C23);
  static const _accent = Color(0xFFE63E00);
  static const _muted = Color(0xFFD3AAA2);

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
    if (!_formKey.currentState!.validate()) return;

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
    return BlocConsumer<FirstRunSetupCubit, FirstRunSetupState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase &&
          current.phase == FirstRunSetupPhase.success,
      listener: (context, state) => widget.onCompleted(),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.explore_outlined,
                          size: 72,
                          color: _accent,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'BeenAround',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Welcome to BeenAround',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Create your administrator account to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, height: 1.5),
                        ),
                        const SizedBox(height: 36),

                        _field(
                          label: 'DISPLAY NAME',
                          controller: _displayNameController,
                          icon: Icons.badge_outlined,
                          validator: (value) {
                            final error = _required(value);
                            if (error != null) return error;
                            if (value!.trim().length > 100) {
                              return 'Maximum 100 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        _field(
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
                          label: 'EMAIL (OPTIONAL)',
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return null;
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
                          label: 'PASSWORD',
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          obscureText: !_showPassword,
                          suffix: IconButton(
                            tooltip: 'Toggle password visibility',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
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
                          label: 'CONFIRM PASSWORD',
                          controller: _confirmPasswordController,
                          icon: Icons.lock_reset_outlined,
                          obscureText: !_showConfirmPassword,
                          suffix: IconButton(
                            tooltip: 'Toggle confirmation visibility',
                            onPressed: () => setState(
                              () =>
                                  _showConfirmPassword = !_showConfirmPassword,
                            ),
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
                          _errorMessage(state.failure),
                        ],

                        const SizedBox(height: 30),

                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: state.isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: state.isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
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

                        const Text(
                          'Self-hosted. Your data stays yours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted),
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _muted),
            suffixIcon: suffix,
            filled: true,
            fillColor: _fieldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorMessage(FirstRunSetupFailure? failure) {
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
        color: const Color(0xFF332020),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFFF9999), fontSize: 13),
      ),
    );
  }
}
