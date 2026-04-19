part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageLayout on _PodcastEpisodeDetailPageState {
  Widget _buildNewLayout(
    BuildContext context,
    PodcastEpisodeModel episode,
  ) {
    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        final isWideScreen = layoutConstraints.maxWidth >
            _PodcastEpisodeDetailPageState._wideLayoutBreakpoint;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: layoutConstraints.maxWidth < Breakpoints.medium
                ? context.spacing.md
                : context.spacing.mdLg,
            vertical: context.spacing.smMd,
          ),
          child: isWideScreen
              ? _buildWideLayout(context, episode)
              : _buildMobileLayout(episode),
        );
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    PodcastEpisodeModel episode,
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
                    SizedBox(height: context.spacing.smMd),
                  ],
                );
              },
            ),
            _buildTabSelector(),
            SizedBox(height: context.spacing.smMd),
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
                      _buildTabWidget(episode, _selectedTabIndex),
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

  Widget _buildMobileLayout(PodcastEpisodeModel episode) {
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
                SizedBox(height: context.spacing.smMd),
              ],
            );
          },
        ),
        _buildTabSelector(),
        SizedBox(height: context.spacing.smMd),
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
                  physics: defaultTargetPlatform == TargetPlatform.iOS
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (index) {
                    _updatePageState(() {
                      _selectedTabIndex = index;
                      _updateHeaderStateForTab();
                    });
                  },
                  children: List<Widget>.generate(pageCount, (index) {
                    return _buildTabSurface(
                      _buildTabWidget(episode, index),
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
