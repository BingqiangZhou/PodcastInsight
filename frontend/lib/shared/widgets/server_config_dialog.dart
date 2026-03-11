import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/network/server_health_service.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
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
  Timer? _debounceTimer;
  StreamSubscription? _healthCheckSubscription;
  List<String> _serverHistory = [];
  static const String _serverHistoryKey = 'server_history_list';
  static const int _maxHistoryItems = 5;

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
    if (_serverUrlController.text.isEmpty) {
      _loadServerUrl();
    }
    _loadServerHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _healthCheckSubscription?.cancel();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadServerUrl() async {
    // Load from provider state which already handles storage
    final serverConfigState = ref.read(serverConfigProvider);
    if (serverConfigState.serverUrl.isNotEmpty) {
      _serverUrlController.text = serverConfigState.serverUrl;
    }
  }

  Future<void> _loadServerHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList(_serverHistoryKey);
    if (!mounted || historyList == null) return;

    setState(() {
      _serverHistory = historyList;
    });
  }

  Future<void> _addToServerHistory(String url) async {
    if (!mounted || url.trim().isEmpty) return;

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
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
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
                                _onServerUrlChanged('', setState);
                              },
                              tooltip: l10n.clear,
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
                onChanged: (value) => _onServerUrlChanged(value, setState),
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
                        _onServerUrlChanged(url, setState);
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
                      _onServerUrlChanged(_localServerUrl, setState);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), color: _getStatusColor(), size: 16),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: _getStatusColor(),
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
                  color: _getStatusColor().withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_connectionStatus) {
      case ConnectionStatus.unverified:
        return Icons.help_outline;
      case ConnectionStatus.verifying:
        return Icons.sync;
      case ConnectionStatus.success:
        return Icons.check_circle;
      case ConnectionStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.dark
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    switch (_connectionStatus) {
      case ConnectionStatus.unverified:
        return theme.colorScheme.onSurfaceVariant;
      case ConnectionStatus.verifying:
        return accent;
      case ConnectionStatus.success:
        return theme.colorScheme.tertiary;
      case ConnectionStatus.failed:
        return theme.colorScheme.error;
    }
  }

  String _getStatusText() {
    final l10n = AppLocalizations.of(context)!;
    switch (_connectionStatus) {
      case ConnectionStatus.unverified:
        return l10n.connection_status_unverified;
      case ConnectionStatus.verifying:
        return l10n.connection_status_verifying;
      case ConnectionStatus.success:
        return l10n.connection_status_success;
      case ConnectionStatus.failed:
        return l10n.connection_status_failed;
    }
  }

  void _onServerUrlChanged(String value, StateSetter setDialogState) {
    _debounceTimer?.cancel();
    _healthCheckSubscription?.cancel();

    if (value.trim().isEmpty) {
      setDialogState(() {
        _connectionStatus = ConnectionStatus.unverified;
        _connectionMessage = null;
      });
      return;
    }

    setDialogState(() {
      _connectionStatus = ConnectionStatus.verifying;
      _connectionMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _verifyServerConnection(value, setDialogState);
    });
  }

  void _verifyServerConnection(String baseUrl, StateSetter setDialogState) {
    final healthService = ServerHealthService(Dio());

    _healthCheckSubscription = healthService
        .verifyConnection(baseUrl)
        .listen(
          (result) {
            if (mounted) {
              setDialogState(() {
                _connectionStatus = result.status;
                _connectionMessage = result.message;
                if (result.responseTimeMs != null) {
                  _connectionMessage =
                      '${result.message} (${result.responseTimeMs}ms)';
                }
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setDialogState(() {
                _connectionStatus = ConnectionStatus.failed;
                _connectionMessage = '连接错误: $e';
              });
            }
          },
        );
  }

  Future<void> _saveServerConfig(BuildContext dialogContext) async {
    final l10n = AppLocalizations.of(context)!;
    final baseUrl = _serverUrlController.text.trim();
    if (baseUrl.isEmpty) return;

    try {
      // Use ServerConfigNotifier to properly save and update DioClient
      await ref.read(serverConfigProvider.notifier).updateServerUrl(baseUrl);
      if (!mounted) return;

      // Add to history after successful save
      await _addToServerHistory(baseUrl);
      if (!mounted) return;

      if (!dialogContext.mounted) return;
      final rootContext = Navigator.of(
        dialogContext,
        rootNavigator: true,
      ).context;
      Navigator.of(dialogContext).pop();
      if (!rootContext.mounted) return;
      showTopFloatingNotice(
        rootContext,
        message: l10n.restore_defaults_success,
        duration: const Duration(milliseconds: 1500),
      );
      widget.onSave?.call();
    } catch (e) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.save_failed(e.toString()),
          isError: true,
        );
      }
    }
  }
}
