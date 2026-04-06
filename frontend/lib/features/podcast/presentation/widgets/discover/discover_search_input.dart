import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;

/// Search input widget for discover page with country selector
class DiscoverSearchInput extends ConsumerStatefulWidget {
  const DiscoverSearchInput({
    required this.searchController, required this.searchFocusNode, required this.onSearchChanged, required this.onClearSearch, required this.onCountryTap, super.key,
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

    final borderSide = _isFocused
        ? BorderSide(color: scheme.primary, width: 1.4)
        : BorderSide(color: scheme.outlineVariant);

    return RepaintBoundary(
      key: const Key('podcast_discover_search_input_boundary'),
      child: Material(
        key: const Key('podcast_discover_search_bar'),
        color: Colors.transparent,
        shadowColor: _isFocused ? extension.shadowXs.color : Colors.transparent,
        elevation: _isFocused ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(extension.cardRadius),
          side: borderSide,
        ),
        child: SizedBox(
        height: widget.isDense ? 44 : 48,
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: widget.isDense ? 10 : 12),
              child: Icon(
                Icons.search,
                size: widget.isDense ? 18 : 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: widget.isDense ? 6 : 8),
            Expanded(
              child: TextField(
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
                    color: theme.colorScheme.onSurfaceVariant,
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Padding(
              padding: EdgeInsets.only(right: widget.isDense ? 6 : 7),
              child: _CountryButton(
                isDense: widget.isDense,
                onTap: widget.onCountryTap,
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                selectedCountry.code.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
