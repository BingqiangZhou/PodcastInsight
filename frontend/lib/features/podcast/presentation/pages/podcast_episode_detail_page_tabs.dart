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

  Widget _buildTabSelector() {
    final labels = _episodeDetailTabLabels();

    return AdaptiveSegmentedControl<int>(
      segments: {
        for (var i = 0; i < labels.length; i++) i: Text(labels[i]),
      },
      selected: _selectedTabIndex,
      onChanged: (index) {
        if (_selectedTabIndex == index) {
          return;
        }
        _updatePageState(() {
          _selectedTabIndex = index;
          _updateHeaderStateForTab();
        });
        if (!_isWideScreen) {
          _pageController.animateToPage(
            index,
            duration: AppDurations.transitionNormal,
            curve: Curves.easeInOutCubic,
          );
        }
      },
    );
  }

  bool get _isWideScreen =>
      MediaQuery.sizeOf(context).width >=
      _PodcastEpisodeDetailPageState._wideLayoutBreakpoint;
}
