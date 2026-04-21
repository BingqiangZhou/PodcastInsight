import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/network/server_health_service.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';

class ServerConfigDialog extends ConsumerStatefulWidget {
  const ServerConfigDialog({super.key, this.initialUrl, this.onSave});
  final String? initialUrl;
  final VoidCallback? onSave;

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late TextEditingController _serverUrlController;
  String _selectedProtocol = 'https://';
  ConnectionStatus _connectionStatus = ConnectionStatus.unverified;
  String? _connectionMessage;
  late final ServerHealthService _healthService;
  Timer? _debounceTimer;
  StreamSubscription? _healthCheckSubscription;
  bool _isDisposed = false;

  static const List<String> _protocols = ['https://', 'http://'];

  String get _fullUrl {
    var host = _serverUrlController.text.trim();
    for (final scheme in _protocols) {
      if (host.startsWith(scheme)) {
        host = host.substring(scheme.length);
        break;
      }
    }
    if (host.startsWith('http:')) {
      host = host.substring(5);
    } else if (host.startsWith('https:')) {
      host = host.substring(6);
    }
    return '$_selectedProtocol$host';
  }

  static String _stripScheme(String url) {
    for (final scheme in _protocols) {
      if (url.startsWith(scheme)) {
        return url.substring(scheme.length);
      }
    }
    return url;
  }

  static String _detectProtocol(String url) {
    if (url.startsWith('https://')) return 'https://';
    if (url.startsWith('http://')) return 'http://';
    return 'https://';
  }

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _healthService = ref.read(serverHealthServiceFactoryProvider)();

    var initialUrl = widget.initialUrl ?? '';
    if (initialUrl.isEmpty) {
      final serverConfigState = ref.read(serverConfigProvider);
      if (serverConfigState.serverUrl.isNotEmpty) {
        initialUrl = serverConfigState.serverUrl;
      }
    }

    if (initialUrl.isNotEmpty) {
      _selectedProtocol = _detectProtocol(initialUrl);
      _serverUrlController.text = _stripScheme(initialUrl);
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < Breakpoints.medium;
    final dialogWidth = isMobile ? screenWidth - context.spacing.xxl : 500.0;
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(context.spacing.md),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.xlRadius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.backend_api_server_config,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: context.spacing.md),
                SizedBox(
                  width: double.infinity,
                  child: _buildConnectionStatusPanel(),
                ),
                SizedBox(height: context.spacing.smMd),
                TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.backend_api_url_label,
                    hintText: l10n.backend_api_url_hint,
                    border: const OutlineInputBorder(),
                    errorText: _connectionStatus == ConnectionStatus.failed
                        ? _connectionMessage ?? l10n.connection_error_hint
                        : null,
                    prefixIcon: _buildProtocolToggle(scheme),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
                SizedBox(height: context.spacing.sm),
                Text(
                  l10n.backend_api_description,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    Flexible(
                      child: TextButton(
                        onPressed: _connectionStatus == ConnectionStatus.success
                            ? () => _saveServerConfig(context)
                            : null,
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolToggle(ColorScheme scheme) {
    return AdaptiveInkWell(
      onTap: () {
        final newValue = _selectedProtocol == 'https://' ? 'http://' : 'https://';
        setState(() {
          _selectedProtocol = newValue;
        });
        _onServerUrlChanged(_serverUrlController.text);
      },
      borderRadius: AppRadius.smRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedProtocol.replaceAll('://', '').toUpperCase(),
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.swap_horiz,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 20,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
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
      padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.sm),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.smRadius,
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          SizedBox(width: context.spacing.sm),
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_connectionMessage != null &&
              _connectionStatus != ConnectionStatus.failed) ...[
            SizedBox(width: context.spacing.sm),
            Flexible(
              child: Text(
                _connectionMessage!,
                style: theme.textTheme.labelMedium?.copyWith(
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

    var host = value.trim();
    var detectedProtocol = _selectedProtocol;
    var schemeChanged = false;
    for (final scheme in _protocols) {
      if (host.startsWith(scheme)) {
        detectedProtocol = scheme;
        host = host.substring(scheme.length);
        schemeChanged = true;
        break;
      }
    }

    if (schemeChanged && detectedProtocol != _selectedProtocol) {
      _selectedProtocol = detectedProtocol;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final sel = _serverUrlController.selection;
          _serverUrlController.text = host;
          if (sel.start > host.length) {
            _serverUrlController.selection = TextSelection.collapsed(offset: host.length);
          }
        }
      });
    }

    if (host.isEmpty) {
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

    final fullUrl = schemeChanged ? '$detectedProtocol$host' : _fullUrl;
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _verifyServerConnection(fullUrl);
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
              _connectionMessage = context.l10n.connection_error_prefix(e.toString());
            });
          },
        );
  }

  Future<void> _saveServerConfig(BuildContext dialogContext) async {
    final l10n = context.l10n;
    final baseUrl = _fullUrl;
    if (baseUrl == _selectedProtocol) return;

    final currentUrl = ref.read(serverConfigProvider).serverUrl;
    if (currentUrl == baseUrl) {
      Navigator.of(dialogContext).pop();
      return;
    }

    final confirmed = await showAppDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog.adaptive(
        backgroundColor: Colors.transparent,
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

    showAppDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(ctx.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: ctx.spacing.md,
                  height: ctx.spacing.md,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
                SizedBox(height: ctx.spacing.lg),
                Text(l10n.profile_server_switch_clearing),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await ref.read(serverConfigProvider.notifier).updateServerUrl(baseUrl);
      if (_isDisposed || !mounted) return;

      if (dialogContext.mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        Navigator.of(dialogContext).pop();
      }

      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.profile_server_switch_success,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final rootContext = appNavigatorKey.currentContext;
          if (rootContext != null && rootContext.mounted) {
            rootContext.go('/login');
          }
        });
      }

      widget.onSave?.call();
    } catch (e) {
      if (_isDisposed || !mounted) return;

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
