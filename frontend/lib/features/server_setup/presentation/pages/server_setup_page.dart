import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/server_setup_cubit.dart';
import '../../application/server_setup_state.dart';

class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  static const _background = Color(0xFF111217);
  static const _fieldBackground = Color(0xFF1B1C23);
  static const _accent = Color(0xFFE63E00);
  static const _mutedText = Color(0xFFD3AAA2);

  final _serverController = TextEditingController();

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [_buildHeader(), _buildForm(), _buildFooter()],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          _buildCompass(),
          const SizedBox(height: 24),
          const Text(
            'BeenAround',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE7E5EB),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Connect to your server',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
              color: Color(0xFFE7E5EB),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your travels. Your server. Your story.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFFF0A89D)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter your BeenAround server address to\nget started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: _mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass() {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1D1E25),
              border: Border.all(color: const Color(0xFF343039)),
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 43,
              color: Color(0xFF6F5150),
            ),
          ),
          Positioned(
            right: 0,
            top: 28,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: _background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                size: 22,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return BlocBuilder<ServerSetupCubit, ServerSetupState>(
      builder: (context, state) {
        final cubit = context.read<ServerSetupCubit>();

        final isBusy = state.isChecking || state.isSaving;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SERVER ADDRESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: _mutedText,
                ),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: _serverController,
                enabled: !state.isSaving,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: cubit.addressChanged,
                onSubmitted: (_) => cubit.testConnection(),
                style: const TextStyle(fontSize: 15, color: Color(0xFFE7E5EB)),
                decoration: InputDecoration(
                  hintText: 'https://beenaround.example.com',
                  hintStyle: const TextStyle(color: Color(0xFF76504C)),
                  prefixIcon: const Icon(
                    Icons.dns_outlined,
                    color: _mutedText,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _fieldBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Connect to your own self-hosted BeenAround instance '
                'or private server.',
                style: TextStyle(fontSize: 12, height: 1.4, color: _mutedText),
              ),

              if (state.showHttpWarning) ...[
                const SizedBox(height: 16),
                _buildHttpWarning(),
              ],

              const SizedBox(height: 24),

              // Secondary action: verify the server.
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : cubit.testConnection,
                  icon: state.isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(
                    state.isChecking
                        ? 'Testing Connection...'
                        : 'Test Connection',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE7E5EB),
                    side: const BorderSide(color: Color(0xFF39343B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              if (state.phase == ServerSetupPhase.available ||
                  state.phase == ServerSetupPhase.unavailable ||
                  state.phase == ServerSetupPhase.incompatible ||
                  state.phase == ServerSetupPhase.saveFailed) ...[
                const SizedBox(height: 16),
                _buildConnectionStatus(state),
              ],

              const SizedBox(height: 16),

              // Primary action: enabled only after successful verification.
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: state.canConnect ? cubit.connect : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF34343A),
                    disabledForegroundColor: const Color(0xFF88888F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Connect to Server',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _fieldBackground,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: _mutedText),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Self-hosted. Your data stays yours.',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(fontSize: 12, color: _mutedText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'BEENAROUND MOBILE CLIENT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: Color(0xFF76504C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHttpWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF33271B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF76532A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFFFB74D)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unencrypted connection. HTTP does not protect '
              'your login credentials or travel data while in transit.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFFFFD6A0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(ServerSetupState state) {
    final (color, icon, title, description) = switch (state.phase) {
      ServerSetupPhase.available => (
        const Color(0xFF4CAF80),
        Icons.check_circle_outline_rounded,
        'Server available',
        'BeenAround server verified.',
      ),
      ServerSetupPhase.unavailable => (
        const Color(0xFFFF7373),
        Icons.error_outline_rounded,
        'Unable to reach server',
        'Check the address and try again.',
      ),
      ServerSetupPhase.incompatible => (
        const Color(0xFFFF7373),
        Icons.error_outline_rounded,
        'Incompatible server',
        'This address does not appear to host BeenAround.',
      ),
      ServerSetupPhase.saveFailed => (
        const Color(0xFFFF7373),
        Icons.error_outline_rounded,
        'Unable to save server',
        'Please try again.',
      ),
      _ => (Colors.transparent, Icons.info_outline, '', ''),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: _mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
