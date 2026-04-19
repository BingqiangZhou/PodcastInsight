import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;

/// Search input widget for discover page with country selector.
///
/// Uses a filled surface container background with a prominent border
/// and focus glow effect for better visual prominence.
class DiscoverSearchInput extends ConsumerStatefulWidget {
  const DiscoverSearchInput({
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onCountryTap,
    super.key,
    this.searchMode = search.PodcastSearchMode.podcasts,
    this.isDense = false,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onCountryTap;
  final search.PodcastSearchMode searchMode;
  final bool isDense;

  @override
  ConsumerState<DiscoverSearchInput> createState() =>
      _DiscoverSearchInputState();
}

class _DiscoverSearchInputState extends ConsumerState<DiscoverSearchInput> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.searchFocusNode.addListener(_onFocusChange);
    _isFocused = widget.searchFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant DiscoverSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFocusNode != widget.searchFocusNode) {
      oldWidget.searchFocusNode.removeListener(_onFocusChange);
      widget.searchFocusNode.addListener(_onFocusChange);
      _isFocused = widget.searchFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.searchFocusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.searchFocusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    final hintLabel =
        widget.searchMode == search.PodcastSearchMode.episodes
            ? l10n.podcast_search_section_episodes
            : l10n.podcast_search_section_podcasts;
    final isZh =
        Localizations.localeOf(context).languageCode.startsWith('zh');
    final hintText = isZh
        ? '${l10n.search}$hintLabel...'
        : '${l10n.search} $hintLabel...';

    final borderColor = _isFocused
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.5);
    final borderWidth = _isFocused ? 1.6 : 1.0;
    final backgroundColor = _isFocused
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHighest;

    return RepaintBoundary(
      key: const Key('podcast_discover_search_input_boundary'),
      child: AnimatedContainer(
        key: const Key('podcast_discover_search_bar'),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: widget.isDense ? 44 : 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(extension.cardRadius),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 2,
                    spreadRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: widget.isDense ? context.spacing.smMd : context.spacing.md,
              ),
              child: Icon(
                Icons.search,
                size: widget.isDense ? 18 : 20,
                color: _isFocused
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(
              width: widget.isDense ? context.spacing.smMd : context.spacing.sm,
            ),
            Expanded(
              child: PlatformHelper.isIOS(context)
                  ? CupertinoTextField(
                      key: const Key('podcast_discover_search_input'),
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium,
                      placeholder: hintText,
                      placeholderStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      decoration: const BoxDecoration(),
                      padding: EdgeInsets.zero,
                      onChanged: widget.onSearchChanged,
                    )
                  : TextField(
                      key: const Key('podcast_discover_search_input'),
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: hintText,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.searchController,
              builder: (context, value, _) {
                if (value.text.isNotEmpty) {
                  return IconButton(
                    onPressed: widget.onClearSearch,
                    icon: Icon(
                      Icons.clear,
                      size: widget.isDense ? 16 : 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Padding(
              padding: EdgeInsets.only(
                right: widget.isDense ? context.spacing.smMd : context.spacing.smMd + 1,
              ),
              child: _CountryButton(
                isDense: widget.isDense,
                onTap: widget.onCountryTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryButton extends ConsumerWidget {
  const _CountryButton({
    required this.isDense,
    required this.onTap,
  });

  final bool isDense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedCountry = ref.watch(
      countrySelectorProvider.select((state) => state.selectedCountry),
    );
    final height = isDense ? 30.0 : 32.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('podcast_discover_country_button'),
        borderRadius: BorderRadius.circular(height / 2),
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(width: context.spacing.xs),
              Text(
                selectedCountry.code.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: context.spacing.xs + context.spacing.xs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
