import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';

/// 国家/地区选择器下拉菜单
///
/// 仿照图片设计：
/// 1. 顶部显示当前选中国家（带下拉箭头）
/// 2. 常用地区：水平滚动的快捷按钮（带国旗）
/// 3. 所有地区：可滚动列表（显示国家代码+名称+对勾）
class CountrySelectorDropdown extends ConsumerStatefulWidget {
  const CountrySelectorDropdown({
    super.key,
    this.onCountryChanged,
  });

  final ValueChanged<PodcastCountry>? onCountryChanged;

  @override
  ConsumerState<CountrySelectorDropdown> createState() =>
      _CountrySelectorDropdownState();
}

class _CountrySelectorDropdownState
    extends ConsumerState<CountrySelectorDropdown> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final countryState = ref.watch(countrySelectorProvider);
    final countryNotifier = ref.read(countrySelectorProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 所有地区
          _buildAllRegionsSection(
            context,
            countryState.selectedCountry,
            countryNotifier,
            l10n,
          ),
        ],
      ),
    );
  }

  /// 构建所有地区部分
  Widget _buildAllRegionsSection(
    BuildContext context,
    PodcastCountry selectedCountry,
    CountrySelectorNotifier countryNotifier,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              l10n.podcast_country_label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : colorScheme.onSurface,
              ),
            ),
          ),
          // 所有地区列表（可滚动）
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: ListView.separated(
              itemCount: PodcastCountry.values.length,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final country = PodcastCountry.values[index];
                final isSelected = country == selectedCountry;

                return _buildAllRegionItem(
                  context,
                  country,
                  isSelected,
                  () => _selectCountry(country, countryNotifier),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建所有地区列表项
  Widget _buildAllRegionItem(
    BuildContext context,
    PodcastCountry country,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foregroundColor =
        isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.45)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    country.code.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: foregroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getCountryName(country, context.l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: foregroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 22,
                    color: foregroundColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 选择国家
  void _selectCountry(PodcastCountry country, CountrySelectorNotifier countryNotifier) {
    countryNotifier.selectCountry(country);
    widget.onCountryChanged?.call(country);
  }

  /// 获取国家名称
  String _getCountryName(PodcastCountry country, AppLocalizations l10n) {
    return switch (country.localizationKey) {
      'podcast_country_china' => l10n.podcast_country_china,
      'podcast_country_usa' => l10n.podcast_country_usa,
      'podcast_country_japan' => l10n.podcast_country_japan,
      'podcast_country_uk' => l10n.podcast_country_uk,
      'podcast_country_germany' => l10n.podcast_country_germany,
      'podcast_country_france' => l10n.podcast_country_france,
      'podcast_country_canada' => l10n.podcast_country_canada,
      'podcast_country_australia' => l10n.podcast_country_australia,
      'podcast_country_korea' => l10n.podcast_country_korea,
      'podcast_country_taiwan' => l10n.podcast_country_taiwan,
      'podcast_country_hong_kong' => l10n.podcast_country_hong_kong,
      'podcast_country_india' => l10n.podcast_country_india,
      'podcast_country_brazil' => l10n.podcast_country_brazil,
      'podcast_country_mexico' => l10n.podcast_country_mexico,
      'podcast_country_spain' => l10n.podcast_country_spain,
      'podcast_country_italy' => l10n.podcast_country_italy,
      _ => country.code.toUpperCase(),
    };
  }
}
