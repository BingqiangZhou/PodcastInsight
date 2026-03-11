part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageLayout on _PodcastEpisodeDetailPageState {
  Widget _buildNewLayout(BuildContext context, dynamic episode) {
    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        // Use split-pane layout on desktop/tablet widths.
        final isWideScreen = layoutConstraints.maxWidth > 800;

        if (isWideScreen) {
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          height: _isHeaderExpanded ? 90 : 100,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildLeftSidebar(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      key: const Key('podcast_episode_detail_wide_right_pane'),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (scrollNotification) {
                              _handleAutoCollapseOnRead(scrollNotification);
                              if (scrollNotification
                                  is ScrollUpdateNotification) {
                                _recordScrollMetrics(
                                  scrollNotification.metrics,
                                );
                              }
                              return false;
                            },
                            child: Container(
                              padding: EdgeInsets.only(
                                top: _isHeaderExpanded ? 90 : 16,
                                right: 16,
                                bottom: 16,
                              ),
                              child: _buildTabContent(episode),
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
                  ),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                top: 0,
                left: 0,
                right: _isHeaderExpanded ? 0 : null,
                width: _isHeaderExpanded ? null : 200,
                child: _buildAnimatedHeader(episode),
              ),
              if (!_isHeaderExpanded)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: _buildCollapsedFloatingActions(
                    episode,
                    (AppLocalizations.of(context) ?? AppLocalizationsEn()),
                  ),
                ),
            ],
          );
        } else {
          final topPadding = MediaQuery.of(context).padding.top;
          final totalTopPadding = topPadding > 0 ? topPadding + 8.0 : 8.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(top: totalTopPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRect(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _scrollOffset,
                        builder: (context, _, _) {
                          return Align(
                            alignment: Alignment.topCenter,
                            heightFactor: _headerClipHeight / 100.0,
                            child: AnimatedOpacity(
                              opacity: _headerOpacity,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeInOut,
                              child: _buildHeader(episode),
                            ),
                          );
                        },
                      ),
                    ),

                    _buildTopButtonBar(),
                  ],
                ),
              ),

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
                        children: [
                          // 0 = Shownotes
                          _buildSingleTabContent(episode, 0),
                          // 1 = Transcript
                          _buildSingleTabContent(episode, 1),
                          // 2 = AI Summary
                          _buildSingleTabContent(episode, 2),
                          // 3 = Conversation
                          _buildSingleTabContent(episode, 3),
                        ],
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
      },
    );
  }
}
