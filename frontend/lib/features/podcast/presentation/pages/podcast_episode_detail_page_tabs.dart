part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageTabs on _PodcastEpisodeDetailPageState {
  List<String> _episodeDetailTabLabels() {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return <String>[
      l10n.podcast_tab_shownotes,
      l10n.podcast_tab_transcript,
      l10n.podcast_tab_summary,
    ];
  }

  Widget _buildTopButtonBar({required bool isWide}) {
    if (!isWide) {
      return _buildMobileTopTextBar();
    }

    final labels = _episodeDetailTabLabels();
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    return SurfacePanel(
      key: const Key('podcast_episode_detail_primary_tabs'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.smMd, AppSpacing.smMd, AppSpacing.smMd, AppSpacing.smMd),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: isWide ? 0.24 : 0.18),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List<Widget>.generate(labels.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == labels.length - 1 ? 0 : 8,
                    ),
                    child: _buildTabButton(
                      tabIndex: index,
                      text: labels[index],
                      isSelected: _selectedTabIndex == index,
                      onTap: () {
                        if (_selectedTabIndex == index) {
                          return;
                        }
                        _updatePageState(() {
                          _selectedTabIndex = index;
                          _updateHeaderStateForTab(index);
                        });
                        if (!isWide) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.smMd),
          HeaderCapsuleActionButton(
            key: const Key('podcast_episode_detail_chat_button'),
            tooltip: l10n.podcast_tab_chat,
            icon: Icons.auto_awesome_outlined,
            label: Text(l10n.podcast_tab_chat),
            onPressed: _openChatDrawer,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopTextBar() {
    final labels = _episodeDetailTabLabels();
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    return SurfacePanel(
      key: const Key('podcast_episode_detail_primary_tabs'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.smMd, AppSpacing.md, AppSpacing.smMd),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.18),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List<Widget>.generate(labels.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == labels.length - 1 ? 0 : 14,
                    ),
                    child: _buildTextTabButton(
                      tabIndex: index,
                      text: labels[index],
                      isSelected: _selectedTabIndex == index,
                      onTap: () {
                        if (_selectedTabIndex == index) {
                          return;
                        }
                        _updatePageState(() {
                          _selectedTabIndex = index;
                          _updateHeaderStateForTab(index);
                        });
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.smMd),
          _buildMobileChatAction(l10n),
        ],
      ),
    );
  }

  Widget _buildTextTabButton({
    required int tabIndex,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      key: Key('episode_detail_mobile_tab_$tabIndex'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isSelected)
                Container(
                  key: Key('episode_detail_mobile_tab_indicator_$tabIndex'),
                  width: 24,
                  height: 2,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: AppRadius.pillRadius,
                  ),
                )
              else
                const SizedBox(height: AppSpacing.xs / 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileChatAction(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('podcast_episode_detail_chat_button'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: _openChatDrawer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 14,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.podcast_tab_chat,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int tabIndex,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < Breakpoints.medium;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: isCompact ? null : 13,
      color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );

    return Material(
      key: Key('episode_detail_mobile_tab_$tabIndex'),
      color: isSelected
          ? colorScheme.primary.withValues(alpha: 0.16)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgRadius,
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 10,
            isCompact ? 10 : 7,
            isCompact ? 12 : 10,
            isCompact ? 10 : 7,
          ),
          child: Text(text, style: textStyle),
        ),
      ),
    );
  }
}
