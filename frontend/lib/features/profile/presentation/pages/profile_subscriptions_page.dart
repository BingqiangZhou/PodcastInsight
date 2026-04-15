import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/episode_description_helper.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/add_podcast_dialog.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

class ProfileSubscriptionsPage extends ConsumerStatefulWidget {
  const ProfileSubscriptionsPage({super.key});

  @override
  ConsumerState<ProfileSubscriptionsPage> createState() =>
      _ProfileSubscriptionsPageState();
}

class _ProfileSubscriptionsPageState
    extends ConsumerState<ProfileSubscriptionsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(podcastSubscriptionProvider.notifier)
          .loadSubscriptions()
          .catchError((error, stackTrace) {
            logger.AppLogger.warning(
              '[ProfileSubscriptions] Initial subscriptions load failed: $error',
            );
          });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }

    final state = ref.read(podcastSubscriptionProvider);
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }

    ref.read(podcastSubscriptionProvider.notifier).loadMoreSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(
      podcastSubscriptionProvider.select(
        (value) => (
          subscriptions: value.subscriptions,
          hasMore: value.hasMore,
          isLoading: value.isLoading,
          isLoadingMore: value.isLoadingMore,
          total: value.total,
          error: value.error,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: ResponsiveContainer(
                maxWidth: 1480,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderPanel(context),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref
                            .read(podcastSubscriptionProvider.notifier)
                            .refreshSubscriptions(),
                        child: _buildBody(
                          context,
                          l10n,
                          subscriptions: state.subscriptions,
                          hasMore: state.hasMore,
                          isLoading: state.isLoading,
                          isLoadingMore: state.isLoadingMore,
                          total: state.total,
                          error: state.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPanel(BuildContext context) {
    final l10n = context.l10n;
    final isMobile =
        MediaQuery.sizeOf(context).width < Breakpoints.medium;
    return CompactHeaderPanel(
      title: l10n.profile_subscriptions,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            context,
            key: const Key('profile_subscriptions_action_add'),
            tooltip: l10n.podcast_add_podcast,
            icon: Icons.add,
            onPressed: () {
              showAppDialog(
                context: context,
                builder: (context) => const AddPodcastDialog(),
              );
            },
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            HeaderCapsuleActionButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              circular: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return HeaderCapsuleActionButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      circular: true,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n, {
    required List<PodcastSubscriptionModel> subscriptions,
    required bool hasMore,
    required bool isLoading,
    required bool isLoadingMore,
    required int total,
    required String? error,
  }) {
    if (isLoading && subscriptions.isEmpty) {
      return _buildPanelScaffold(
        context,
        title: l10n.profile_subscriptions,
        subtitle: l10n.profile_subscriptions_subtitle,
        child: LoadingStatusContent(
          key: const Key('profile_subscriptions_loading_content'),
          title: l10n.loading,
          spinnerSize: 28,
          gapAfterSpinner: 12,
        ),
        bare: true,
      );
    }

    if (error != null && subscriptions.isEmpty) {
      return _buildPanelScaffold(
        context,
        title: l10n.profile_subscriptions,
        subtitle: l10n.profile_subscriptions_subtitle,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (subscriptions.isEmpty) {
      return _buildPanelScaffold(
        context,
        title: l10n.profile_subscriptions,
        subtitle: l10n.profile_subscriptions_subtitle,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.subscriptions_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.podcast_no_subscriptions,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.feed_no_subscriptions_hint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: appThemeOf(context).cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: AppSectionHeader(
              title: l10n.profile_subscriptions,
              subtitle: l10n.profile_subscriptions_count(total),
              hideTitle: true,
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: subscriptions.length + 1,
              itemBuilder: (context, index) {
                if (index == subscriptions.length) {
                  return _buildLoadingIndicator(
                    context,
                    hasMore,
                    isLoadingMore,
                    total,
                    l10n,
                  );
                }

                final subscription = subscriptions[index];
                return _buildSubscriptionCard(context, subscription, l10n);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelScaffold(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    bool bare = false,
  }) {
    if (bare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: AppSectionHeader(title: title, subtitle: subtitle),
          ),
          Expanded(child: Center(child: child)),
        ],
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: appThemeOf(context).cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: AppSectionHeader(title: title, subtitle: subtitle),
          ),
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    PodcastSubscriptionModel subscription,
    AppLocalizations l10n,
  ) {
    return RepaintBoundary(
      key: ValueKey('subscription_card_${subscription.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push(
                '/podcast/episodes/${subscription.id}',
                extra: subscription,
              );
            },
            borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
            child: SizedBox(
            key: ValueKey('profile_subscription_card_content_${subscription.id}'),
            height: kPodcastRowCardTargetHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kPodcastRowCardHorizontalPadding,
                vertical: 6,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      kPodcastRowCardImageRadius,
                    ),
                    child: PodcastImageWidget(
                      imageUrl: subscription.imageUrl,
                      width: kPodcastRowCardImageSize,
                      height: kPodcastRowCardImageSize,
                      iconSize: 24,
                      iconColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: kPodcastRowCardHorizontalGap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subscription.description != null
                              ? EpisodeDescriptionHelper.stripHtmlTags(
                                  subscription.description,
                                )
                              : l10n.podcast_description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLoadingIndicator(
    BuildContext context,
    bool hasMore,
    bool isLoadingMore,
    int total,
    AppLocalizations l10n,
  ) {
    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '${l10n.profile_subscriptions}: $total',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
