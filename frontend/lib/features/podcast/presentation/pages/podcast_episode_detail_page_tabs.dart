part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageTabs on _PodcastEpisodeDetailPageState {
  List<String> _episodeDetailTabLabels() {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    return <String>[
      l10n.podcast_tab_shownotes,
      l10n.podcast_tab_transcript,
      l10n.podcast_tab_summary,
    ];
  }

  Widget _buildTopButtonBar({required bool isWide}) {
    final labels = _episodeDetailTabLabels();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final chatDensity = screenWidth < 360
        ? HeaderCapsuleActionButtonDensity.iconOnly
        : screenWidth < 600
        ? HeaderCapsuleActionButtonDensity.compact
        : HeaderCapsuleActionButtonDensity.regular;
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());

    return GlassPanel(
      key: const Key('podcast_episode_detail_primary_tabs'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: isWide ? 0.24 : 0.18),
      showHighlight: false,
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
          const SizedBox(width: 12),
          HeaderCapsuleActionButton(
            key: const Key('podcast_episode_detail_chat_button'),
            tooltip: l10n.podcast_tab_chat,
            icon: Icons.auto_awesome_outlined,
            density: chatDensity,
            label: chatDensity == HeaderCapsuleActionButtonDensity.iconOnly
                ? null
                : Text(l10n.podcast_tab_chat),
            onPressed: _openChatDrawer,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int tabIndex,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = DefaultTextStyle.of(context).style.copyWith(
      color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      fontSize: isCompact ? 12 : 13,
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
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 14,
            isCompact ? 10 : 11,
            isCompact ? 12 : 14,
            isCompact ? 10 : 11,
          ),
          child: Text(text, style: textStyle),
        ),
      ),
    );
  }
}
