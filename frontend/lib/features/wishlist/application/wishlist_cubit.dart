import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../domain/wishlist_repository.dart';
import 'wishlist_state.dart';

class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit({required WishlistRepository repository})
    : _repository = repository,
      super(const WishlistState());

  final WishlistRepository _repository;

  int _requestGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(WishlistState(phase: WishlistPhase.loading, entries: state.entries));

    try {
      final entries = await _repository.getWishlistEntries();

      if (!_isCurrent(generation)) return;

      emit(
        WishlistState(
          phase: WishlistPhase.ready,
          entries: List.unmodifiable(entries),
        ),
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        WishlistState(
          phase: WishlistPhase.failure,
          entries: state.entries,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        WishlistState(
          phase: WishlistPhase.failure,
          entries: state.entries,
          errorMessage: 'Unable to load your wishlist.',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() {
    ++_requestGeneration;
    return super.close();
  }
}
