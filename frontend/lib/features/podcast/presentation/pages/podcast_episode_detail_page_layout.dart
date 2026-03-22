part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageLayout on _PodcastEpisodeDetailPageState {
  Widget _buildNewLayout(
    BuildContext context,
    PodcastEpisodeDetailResponse episode,
  ) {
    final safeTop = MediaQuery.viewPaddingOf(context).top;

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        final isWideScreen =
            layoutConstraints.maxWidth >
            _PodcastEpisodeDetailPageState._wideLayoutBreakpoint;
        final outerPadding = EdgeInsets.fromLTRB(
          layoutConstraints.maxWidth < AppBreakpoints.medium ? 16 : 20,
          (layoutConstraints.maxWidth < AppBreakpoints.medium ? 12 : 16) +
              safeTop,
          layoutConstraints.maxWidth < AppBreakpoints.medium ? 16 : 20,
          16,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            const AppPageBackdrop(),
            Padding(
              padding: outerPadding,
              child: isWideScreen
                  ? _buildWideLayout(context, episode)
                  : _buildMobileLayout(episode),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    PodcastEpisodeDetailResponse episode,
  ) {
    final tokens = appThemeOf(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tokens.contentMaxWidth - 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isHeaderExpandedNotifier,
              builder: (context, isExpanded, _) {
                if (!isExpanded) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    _buildAnimatedHeader(episode),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            _buildTopButtonBar(isWide: true),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      _handleAutoCollapseOnRead(scrollNotification);
                      if (scrollNotification is ScrollUpdateNotification) {
                        _recordScrollMetrics(scrollNotification.metrics);
                      }
                      return false;
                    },
                    child: _buildTabSurface(
                      _buildTabContent(episode),
                      key: const Key('podcast_episode_detail_primary_content'),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToTopButton,
                    builder: (context, shouldShow, _) {
                      if (!shouldShow) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 16,
                        bottom: 16,
                        child: _buildScrollToTopButton(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(PodcastEpisodeDetailResponse episode) {
    final pageCount = _episodeDetailTabLabels().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _isHeaderExpandedNotifier,
          builder: (context, isExpanded, _) {
            if (!isExpanded) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                _buildHeader(episode),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        _buildTopButtonBar(isWide: false),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  _handleAutoCollapseOnRead(scrollNotification);
                  if (scrollNotification is ScrollUpdateNotification) {
                    _recordScrollMetrics(scrollNotification.metrics);
                  }
                  return false;
                },
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    _updatePageState(() {
                      _selectedTabIndex = index;
                      _updateHeaderStateForTab(index);
                    });
                  },
                  children: List<Widget>.generate(pageCount, (index) {
                    return _buildTabSurface(
                      _buildSingleTabContent(episode, index),
                      key: Key(
                        'podcast_episode_detail_mobile_content_surface_$index',
                      ),
                    );
                  }),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showScrollToTopButton,
                builder: (context, shouldShow, _) {
                  if (!shouldShow) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    right: 0,
                    bottom: 0,
                    child: _buildScrollToTopButton(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
