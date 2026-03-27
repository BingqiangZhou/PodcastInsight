import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/network/server_health_service.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server configuration dialog widget
/// Can be used in both settings page and login screen
class ServerConfigDialog extends ConsumerStatefulWidget {
  final String? initialUrl;
  final VoidCallback? onSave;

  const ServerConfigDialog({super.key, this.initialUrl, this.onSave});

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late TextEditingController _serverUrlController;
  ConnectionStatus _connectionStatus = ConnectionStatus.unverified;
  String? _connectionMessage;
  late final ServerHealthService _healthService;
  Timer? _debounceTimer;
  StreamSubscription? _healthCheckSubscription;
  List<String> _serverHistory = [];
  static const String _serverHistoryKey = 'server_history_list';
  static const int _maxHistoryItems = 5;
  bool _isDisposed = false;

  /// Get local server URL based on platform
  String get _localServerUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: widget.initialUrl ?? '');
    _healthService = ref.read(serverHealthServiceFactoryProvider)();
    if (_serverUrlController.text.isEmpty) {
      final serverConfigState = ref.read(serverConfigProvider);
      if (serverConfigState.serverUrl.isNotEmpty) {
        _serverUrlController.text = serverConfigState.serverUrl;
      }
    }
    _loadServerHistory();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _healthCheckSubscription?.cancel();
    _healthCheckSubscription = null;
    _healthService.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadServerHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList(_serverHistoryKey);
    if (_isDisposed || !mounted || historyList == null) return;

    setState(() {
      _serverHistory = historyList;
    });
  }

  Future<void> _addToServerHistory(String url) async {
    if (_isDisposed || !mounted || url.trim().isEmpty) return;

    final normalizedUrl = url.trim();
    setState(() {
      // Remove if already exists
      _serverHistory.remove(normalizedUrl);
      // Add to front
      _serverHistory.insert(0, normalizedUrl);
      // Keep only max items
      if (_serverHistory.length > _maxHistoryItems) {
        _serverHistory = _serverHistory.sublist(0, _maxHistoryItems);
      }
    });

    // Save to storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_serverHistoryKey, _serverHistory);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < Breakpoints.medium;
    final dialogWidth = isMobile ? screenWidth - 32 : 500.0;
    return AlertDialog(
      insetPadding: isMobile ? const EdgeInsets.all(16) : null,
      title: Text(l10n.backend_api_server_config),
      content: SizedBox(
        width: dialogWidth,
        // FIX: Wrap in SingleChildScrollView to prevent overflow when keyboard is shown
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status row (icon and text in same row) - width matches TextField
              SizedBox(
                width: double.infinity,
                child: _buildConnectionStatusPanel(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serverUrlController,
                decoration: InputDecoration(
                  labelText: l10n.backend_api_url_label,
                  hintText: l10n.backend_api_url_hint,
                  border: const OutlineInputBorder(),
                  errorText: _connectionStatus == ConnectionStatus.failed
                      ? _connectionMessage ?? l10n.connection_error_hint
                      : null,
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _serverUrlController,
                    builder: (context, value, child) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _serverUrlController.clear();
                                _onServerUrlChanged('');
                              },
                              tooltip: l10n.clear,
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
                onChanged: _onServerUrlChanged,
              ),
              const SizedBox(height: 8),

              // Description note (below input, above history)
              Text(
                l10n.backend_api_description,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              // Server history list
              if (_serverHistory.isNotEmpty) ...[
                Text(
                  l10n.server_history_title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _serverHistory.map((url) {
                    return InputChip(
                      label: Text(url, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        _serverUrlController.text = url;
                        _onServerUrlChanged(url);
                      },
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              // Action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Local server button
                  OutlinedButton.icon(
                    onPressed: () {
                      _serverUrlController.text = _localServerUrl;
                      _onServerUrlChanged(_localServerUrl);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.computer, size: 16),
                    label: Text(l10n.use_local_url),
                  ),
                  const SizedBox(height: 8),
                  // Cancel and Save buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _connectionStatus == ConnectionStatus.success
                            ? () => _saveServerConfig(context)
                            : null,
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: const [],
    );
  }

  Widget _buildConnectionStatusPanel() {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final accent = theme.brightness == Brightness.dark
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    late final IconData statusIcon;
    late final Color statusColor;
    late final String statusText;

    switch (_connectionStatus) {
      case ConnectionStatus.unverified:
        statusIcon = Icons.help_outline;
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusText = l10n.connection_status_unverified;
      case ConnectionStatus.verifying:
        statusIcon = Icons.sync;
        statusColor = accent;
        statusText = l10n.connection_status_verifying;
      case ConnectionStatus.success:
        statusIcon = Icons.check_circle;
        statusColor = theme.colorScheme.tertiary;
        statusText = l10n.connection_status_success;
      case ConnectionStatus.failed:
        statusIcon = Icons.error;
        statusColor = theme.colorScheme.error;
        statusText = l10n.connection_status_failed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (_connectionMessage != null &&
              _connectionStatus != ConnectionStatus.failed) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _connectionMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onServerUrlChanged(String value) {
    _debounceTimer?.cancel();
    _healthCheckSubscription?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _connectionStatus = ConnectionStatus.unverified;
        _connectionMessage = null;
      });
      return;
    }

    setState(() {
      _connectionStatus = ConnectionStatus.verifying;
      _connectionMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _verifyServerConnection(value);
    });
  }

  void _verifyServerConnection(String baseUrl) {
    _healthCheckSubscription = _healthService
        .verifyConnection(baseUrl)
        .listen(
          (result) {
            if (_isDisposed || !mounted) return;
            setState(() {
              _connectionStatus = result.status;
              _connectionMessage = result.message;
              if (result.responseTimeMs != null) {
                _connectionMessage =
                    '${result.message} (${result.responseTimeMs}ms)';
              }
            });
          },
          onError: (e) {
            if (_isDisposed || !mounted) return;
            setState(() {
              _connectionStatus = ConnectionStatus.failed;
              _connectionMessage = '连接错误: $e';
            });
          },
        );
  }

  Future<void> _saveServerConfig(BuildContext dialogContext) async {
    final l10n = context.l10n;
    final baseUrl = _serverUrlController.text.trim();
    if (baseUrl.isEmpty) return;

    final currentUrl = ref.read(serverConfigProvider).serverUrl;

    // If URL hasn't changed, just close the dialog
    if (currentUrl == baseUrl) {
      Navigator.of(dialogContext).pop();
      return;
    }

    // Show confirmation dialog for server switch
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profile_server_switch_title),
        content: Text(l10n.profile_server_switch_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog (use rootNavigator to show above all other dialogs)
    showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.profile_server_switch_clearing),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // Use ServerConfigNotifier to save and clear data
      await ref.read(serverConfigProvider.notifier).updateServerUrl(baseUrl);
      if (_isDisposed || !mounted) return;

      // Add to history after successful save
      await _addToServerHistory(baseUrl);
      if (_isDisposed || !mounted) return;

      // Close loading dialog and config dialog
      if (dialogContext.mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop(); // Close loading dialog
        Navigator.of(dialogContext).pop(); // Close config dialog
      }

      // Show success message and navigate after dialog is closed
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.profile_server_switch_success,
        );

        // Use addPostFrameCallback to ensure navigation happens after dialogs are closed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Use global navigator key to get root context for navigation
          final rootContext = appNavigatorKey.currentContext;
          if (rootContext != null && rootContext.mounted) {
            rootContext.go('/login');
          }
        });
      }

      widget.onSave?.call();
    } catch (e) {
      if (_isDisposed || !mounted) return;

      // Close loading dialog on error
      if (dialogContext.mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }

      showTopFloatingNotice(
        context,
        message: l10n.save_failed(e.toString()),
        isError: true,
      );
    }
  }
}
