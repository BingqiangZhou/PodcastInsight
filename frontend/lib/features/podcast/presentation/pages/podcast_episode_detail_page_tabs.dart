part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageTabs on _PodcastEpisodeDetailPageState {
  Widget _buildTopButtonBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Shownotes Tab
            _buildTabButton(
              tabIndex: 0,
              text: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_tab_shownotes,
              isSelected: _selectedTabIndex == 0,
              onTap: () {
                if (_selectedTabIndex != 0) {
                  _updatePageState(() {
                    _updateHeaderStateForTab(0);
                  });
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            // Transcript Tab
            _buildTabButton(
              tabIndex: 1,
              text: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_tab_transcript,
              isSelected: _selectedTabIndex == 1,
              onTap: () {
                if (_selectedTabIndex != 1) {
                  _updatePageState(() {
                    _updateHeaderStateForTab(1);
                  });
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            // AI Summary Tab
            _buildTabButton(
              tabIndex: 2,
              text: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_filter_with_summary,
              isSelected: _selectedTabIndex == 2,
              onTap: () {
                if (_selectedTabIndex != 2) {
                  _updatePageState(() {
                    _updateHeaderStateForTab(2);
                  });
                  _pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            // Conversation Tab
            _buildTabButton(
              tabIndex: 3,
              text: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_tab_chat,
              isSelected: _selectedTabIndex == 3,
              onTap: () {
                if (_selectedTabIndex != 3) {
                  _updatePageState(() {
                    _updateHeaderStateForTab(3);
                  });
                  _pageController.animateToPage(
                    3,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shownotes Tab
          _buildSidebarTabButton(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_tab_shownotes,
            _selectedTabIndex == 0,
            () {
              if (_selectedTabIndex != 0) {
                _updatePageState(() {
                  _selectedTabIndex = 0;
                  _updateHeaderStateForTab(0);
                });
              }
            },
          ),
          const SizedBox(height: 8),
          // Transcript Tab
          _buildSidebarTabButton(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_tab_transcript,
            _selectedTabIndex == 1,
            () {
              if (_selectedTabIndex != 1) {
                _updatePageState(() {
                  _selectedTabIndex = 1;
                  _updateHeaderStateForTab(1);
                });
              }
            },
          ),
          const SizedBox(height: 8),
          // AI Summary Tab
          _buildSidebarTabButton(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_filter_with_summary,
            _selectedTabIndex == 2,
            () {
              if (_selectedTabIndex != 2) {
                _updatePageState(() {
                  _selectedTabIndex = 2;
                  _updateHeaderStateForTab(2);
                });
              }
            },
          ),
          const SizedBox(height: 8),
          // Conversation Tab
          _buildSidebarTabButton(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_tab_chat,
            _selectedTabIndex == 3,
            () {
              if (_selectedTabIndex != 3) {
                _updatePageState(() {
                  _selectedTabIndex = 3;
                  _updateHeaderStateForTab(3);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTabButton(
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = DefaultTextStyle.of(context).style.copyWith(
      color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      fontSize: 13,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    final indicatorWidth = textPainter.width;

    return GestureDetector(
      key: Key('episode_detail_mobile_tab_$tabIndex'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 10, top: 6),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: textStyle),
            const SizedBox(height: 6),
            Container(
              key: Key('episode_detail_mobile_tab_indicator_$tabIndex'),
              width: indicatorWidth,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
