import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/history/services/history_service.dart';

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService();
});

final classificationDetailProvider = StreamProvider.autoDispose
    .family<ClassificationRecord?, String>((ref, classificationId) {
  final user = ref.watch(currentUserProvider);
  final userData = ref.watch(userDataProvider).valueOrNull;
  final isAdmin = userData?['role'] == 'admin';

  return ref.watch(historyServiceProvider).watchClassification(
        classificationId,
        currentUserId: user?.uid,
        isAdmin: isAdmin,
      );
});

final myHistoryControllerProvider = StateNotifierProvider.autoDispose<
    HistoryController, AsyncValue<HistoryListState>>((ref) {
  return HistoryController(
    service: ref.watch(historyServiceProvider),
    ref: ref,
    scope: ClassificationScope.mine,
  );
});

final publicHistoryControllerProvider = StateNotifierProvider.autoDispose<
    HistoryController, AsyncValue<HistoryListState>>((ref) {
  return HistoryController(
    service: ref.watch(historyServiceProvider),
    ref: ref,
    scope: ClassificationScope.public,
  );
});

class HistoryListState {
  final List<ClassificationRecord> items;
  final HistoryFilter filter;
  final bool hasMore;
  final bool isLoadingMore;

  const HistoryListState({
    required this.items,
    required this.filter,
    required this.hasMore,
    required this.isLoadingMore,
  });

  factory HistoryListState.initial() {
    return const HistoryListState(
      items: [],
      filter: HistoryFilter(),
      hasMore: true,
      isLoadingMore: false,
    );
  }

  HistoryListState copyWith({
    List<ClassificationRecord>? items,
    HistoryFilter? filter,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return HistoryListState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class HistoryController extends StateNotifier<AsyncValue<HistoryListState>> {
  final HistoryService _service;
  final Ref _ref;
  final ClassificationScope _scope;

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _loadedOnce = false;

  HistoryController({
    required HistoryService service,
    required Ref ref,
    required ClassificationScope scope,
  })  : _service = service,
        _ref = ref,
        _scope = scope,
        super(AsyncData(HistoryListState.initial()));

  Future<void> loadInitial() async {
    if (_loadedOnce) return;
    _loadedOnce = true;
    await refresh();
  }

  Future<void> refresh() async {
    final current = state.valueOrNull ?? HistoryListState.initial();
    state = const AsyncLoading<HistoryListState>();
    _lastDocument = null;

    try {
      final page = await _fetchPage(
        filter: current.filter,
        startAfter: null,
      );
      _lastDocument = page.lastDocument;
      state = AsyncData(
        current.copyWith(
          items: page.items,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetchPage(
        filter: current.filter,
        startAfter: _lastDocument,
      );
      _lastDocument = page.lastDocument ?? _lastDocument;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> setFilter(HistoryFilter filter) async {
    final current = state.valueOrNull ?? HistoryListState.initial();
    state = AsyncData(current.copyWith(filter: filter));
    await refresh();
  }

  Future<void> clearFilters() async {
    final current = state.valueOrNull ?? HistoryListState.initial();
    state = AsyncData(
      current.copyWith(
        filter: HistoryFilter(sortOrder: current.filter.sortOrder),
      ),
    );
    await refresh();
  }

  Future<ClassificationRecordPage> _fetchPage({
    required HistoryFilter filter,
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    final user = _ref.read(currentUserProvider);
    final userData = _ref.read(userDataProvider).valueOrNull;
    return _service.fetchPage(
      scope: _scope,
      filter: filter,
      currentUserId: user?.uid,
      isAdmin: userData?['role'] == 'admin',
      startAfter: startAfter,
    );
  }
}
