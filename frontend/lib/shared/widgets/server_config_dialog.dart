import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/network/server_health_service.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server configuration dialog widget
/// Can be used in both settings page and login screen
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
  List<String> _serverHistory = [];
  static const String _serverHistoryKey = 'server_history_list';
  static const int _maxHistoryItems = 5;
  bool _isDisposed = false;

  static const List<String> _protocols = ['https://', 'http://'];

  /// Combined URL from protocol dropdown + host text input.
  /// Strips any scheme the user may have pasted into the host field.
  String get _fullUrl {
    var host = _serverUrlController.text.trim();
    // Strip scheme if user pasted a full URL
    for (final scheme in _protocols) {
      if (host.startsWith(scheme)) {
        host = host.substring(scheme.length);
        break;
      }
    }
    // Also handle scheme without slashes
    if (host.startsWith('http:')) {
      host = host.substring(5);
    } else if (host.startsWith('https:')) {
      host = host.substring(6);
    }
    return '$_selectedProtocol$host';
  }

  /// Strip scheme from a URL, returning only host:port.
  static String _stripScheme(String url) {
    for (final scheme in _protocols) {
      if (url.startsWith(scheme)) {
        return url.substring(scheme.length);
      }
    }
    return url;
  }

  /// Detect protocol from a full URL.
  static String _detectProtocol(String url) {
    if (url.startsWith('https://')) return 'https://';
    if (url.startsWith('http://')) return 'http://';
    return 'https://';
  }

  /// Get local server URL based on platform
  String get _localServerUrl {
    if (PlatformHelper.isAndroid(context)) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _healthService = ref.read(serverHealthServiceFactoryProvider)();

    // Resolve initial URL: from widget param or current config
    var initialUrl = widget.initialUrl ?? '';
    if (initialUrl.isEmpty) {
      final serverConfigState = ref.read(serverConfigProvider);
      if (serverConfigState.serverUrl.isNotEmpty) {
        initialUrl = serverConfigState.serverUrl;
      }
    }

    // Parse protocol and host from the initial URL
    if (initialUrl.isNotEmpty) {
      _selectedProtocol = _detectProtocol(initialUrl);
      _serverUrlController.text = _stripScheme(initialUrl);
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
    final dialogWidth = isMobile ? screenWidth - context.spacing.xxl : 500.0;
    final scheme = Theme.of(context).colorScheme;
    final isIOS = PlatformHelper.isApple(context);

    final dialogChild = Material(
      color: isIOS ? scheme.surface : scheme.surfaceContainerHigh,
      borderRadius: isIOS ? AppRadius.lgRadius : AppRadius.xlRadius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                l10n.backend_api_server_config,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: context.spacing.md),
              // Connection status row
              SizedBox(
                width: double.infinity,
                child: _buildConnectionStatusPanel(),
              ),
              SizedBox(height: context.spacing.smMd),
              if (isIOS) ...[
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill,
                    borderRadius:
                        BorderRadius.circular(appThemeOf(context).buttonRadius),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.spacing.md,
                          context.spacing.sm,
                          context.spacing.md,
                          0,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _buildCupertinoProtocolDropdown(scheme),
                        ),
                      ),
                      CupertinoTextField(
                        controller: _serverUrlController,
                        placeholder: l10n.backend_api_url_hint,
                        onChanged: _onServerUrlChanged,
                        suffix: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _serverUrlController,
                          builder: (context, value, child) {
                            return value.text.isNotEmpty
                                ? CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(44, 44),
                                    onPressed: () {
                                      _serverUrlController.clear();
                                      _onServerUrlChanged('');
                                    },
                                    child: Icon(
                                      CupertinoIcons.clear_thick_circled,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                        padding: EdgeInsets.fromLTRB(
                          context.spacing.md,
                          context.spacing.sm,
                          context.spacing.md,
                          context.spacing.md,
                        ),
                        decoration: const BoxDecoration(),
                      ),
                    ],
                  ),
                ),
                if (_connectionStatus == ConnectionStatus.failed)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: context.spacing.smMd,
                      top: context.spacing.xs,
                    ),
                    child: Text(
                      _connectionMessage ?? l10n.connection_error_hint,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize:
                            Theme.of(context).textTheme.bodySmall?.fontSize ??
                                12,
                      ),
                    ),
                  ),
              ] else
                TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.backend_api_url_label,
                    hintText: l10n.backend_api_url_hint,
                    border: const OutlineInputBorder(),
                    errorText: _connectionStatus == ConnectionStatus.failed
                        ? _connectionMessage ?? l10n.connection_error_hint
                        : null,
                    prefixIcon: _buildMaterialProtocolDropdown(scheme),
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
              SizedBox(height: context.spacing.sm),
              if (_serverHistory.isNotEmpty) ...[
                Text(
                  l10n.server_history_title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                Wrap(
                  spacing: context.spacing.sm,
                  runSpacing: context.spacing.sm,
                  children: _serverHistory.map((url) {
                    return InputChip(
                      label: Text(url, style: Theme.of(context).textTheme.labelSmall),
                      onPressed: () {
                        setState(() {
                          _selectedProtocol = _detectProtocol(url);
                        });
                        _serverUrlController.text = _stripScheme(url);
                        _onServerUrlChanged(url);
                      },
                      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: scheme.outlineVariant,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: context.spacing.smMd),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedProtocol = 'http://';
                      });
                      _serverUrlController.text = _stripScheme(_localServerUrl);
                      _onServerUrlChanged(_localServerUrl);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(36),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.smRadius,
                      ),
                    ),
                    icon: const Icon(Icons.computer, size: 16),
                    label: Text(l10n.use_local_url),
                  ),
                  SizedBox(height: context.spacing.sm),
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
            ],
          ),
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(context.spacing.md),
      child: dialogChild,
    );
  }

  Widget _buildMaterialProtocolDropdown(ColorScheme scheme) {
    return InkWell(
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

  Widget _buildCupertinoProtocolDropdown(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: _selectedProtocol,
        onValueChanged: (value) {
          if (value != null && value != _selectedProtocol) {
            setState(() {
              _selectedProtocol = value;
            });
            _onServerUrlChanged(_serverUrlController.text);
          }
        },
        children: {
          for (final p in _protocols)
            p: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                p.replaceAll('://', '').toUpperCase(),
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.labelMedium?.fontSize ?? 12,
                  fontWeight: _selectedProtocol == p
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
        },
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

    // Detect if user pasted a full URL with scheme
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
      // Update text controller to show only host part (after current frame)
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
    if (baseUrl == _selectedProtocol) return; // Empty host

    final currentUrl = ref.read(serverConfigProvider).serverUrl;

    // If URL hasn't changed, just close the dialog
    if (currentUrl == baseUrl) {
      Navigator.of(dialogContext).pop();
      return;
    }

    // Show confirmation dialog for server switch
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

    // Show loading dialog (use rootNavigator to show above all other dialogs)
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
