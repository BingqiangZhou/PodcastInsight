import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PodcastPlayerPresentation { collapsed, expanded }

class PodcastPlayerUiState {
  const PodcastPlayerUiState({
    this.presentation = PodcastPlayerPresentation.collapsed,
    this.utilityMenuOpen = false,
  });

  final PodcastPlayerPresentation presentation;
  final bool utilityMenuOpen;

  bool get isExpanded => presentation == PodcastPlayerPresentation.expanded;

  PodcastPlayerUiState copyWith({
    PodcastPlayerPresentation? presentation,
    bool? utilityMenuOpen,
  }) {
    return PodcastPlayerUiState(
      presentation: presentation ?? this.presentation,
      utilityMenuOpen: utilityMenuOpen ?? this.utilityMenuOpen,
    );
  }
}

class PodcastPlayerUiNotifier extends Notifier<PodcastPlayerUiState> {
  @override
  PodcastPlayerUiState build() {
    return const PodcastPlayerUiState();
  }

  void expand() {
    if (state.presentation == PodcastPlayerPresentation.expanded) {
      return;
    }
    state = state.copyWith(
      presentation: PodcastPlayerPresentation.expanded,
      utilityMenuOpen: false,
    );
  }

  void collapse() {
    if (state.presentation == PodcastPlayerPresentation.collapsed &&
        !state.utilityMenuOpen) {
      return;
    }
    state = const PodcastPlayerUiState();
  }

  void togglePresentation() {
    if (state.isExpanded) {
      collapse();
      return;
    }
    expand();
  }

  void openUtilityMenu() {
    if (state.utilityMenuOpen) {
      return;
    }
    state = state.copyWith(utilityMenuOpen: true);
  }

  void closeUtilityMenu() {
    if (!state.utilityMenuOpen) {
      return;
    }
    state = state.copyWith(utilityMenuOpen: false);
  }

  void toggleUtilityMenu() {
    state = state.copyWith(utilityMenuOpen: !state.utilityMenuOpen);
  }
}

final podcastPlayerUiProvider =
    NotifierProvider<PodcastPlayerUiNotifier, PodcastPlayerUiState>(
      PodcastPlayerUiNotifier.new,
    );

final podcastPlayerExpandedProvider = Provider<bool>((ref) {
  return ref.watch(podcastPlayerUiProvider.select((state) => state.isExpanded));
});

final podcastPlayerUtilityMenuOpenProvider = Provider<bool>((ref) {
  return ref.watch(
    podcastPlayerUiProvider.select((state) => state.utilityMenuOpen),
  );
});
