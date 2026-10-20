import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  static const _background = Color(0xFF111217);
  static const _surface = Color(0xFF1B1C23);
  static const _accent = Color(0xFFE63E00);
  static const _muted = Color(0xFFD3AAA2);

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
    if (!_formKey.currentState!.validate()) return;

    context.read<LoginCubit>().submit(
      login: _loginController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          color: _accent,
                          size: 76,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'BeenAround',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sign in to continue your travel story.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, height: 1.5),
                        ),
                        const SizedBox(height: 40),

                        const Text(
                          'USERNAME OR EMAIL',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                            icon: Icons.person_outline,
                            hint: 'Username or email',
                          ),
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          onFieldSubmitted: (_) {
                            if (!state.isSubmitting) _submit();
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
                          _errorMessage(state.failure),
                        ],

                        const SizedBox(height: 32),

                        SizedBox(
                          height: 54,
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
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
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

                        const Text(
                          'Your journeys. Your memories. Your space.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12),
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

  InputDecoration _decoration({
    required IconData icon,
    required String hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent),
      ),
    );
  }

  Widget _errorMessage(LoginFailure? failure) {
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
