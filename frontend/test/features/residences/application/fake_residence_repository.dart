import 'package:beenaround/features/residences/domain/residence.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:beenaround/features/residences/domain/residence_overlap.dart';
import 'package:beenaround/features/residences/domain/residence_repository.dart';

class FakeResidenceRepository implements ResidenceRepository {
  List<Residence> residences = [];
  Object? error;

  Future<List<Residence>> Function()? loadHandler;

  int loadCalls = 0;

  @override
  Future<List<Residence>> getResidences() {
    loadCalls++;

    if (loadHandler != null) {
      return loadHandler!();
    }

    if (error != null) {
      return Future.error(error!);
    }

    return Future.value(residences);
  }

  @override
  Future<Residence> getResidence({required String residenceId}) {
    throw UnimplementedError();
  }

  @override
  Future<Residence> createResidence({
    required ResidenceInput input,
    ResidenceOverlapProposal? overlapConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Residence> updateResidence({
    required String residenceId,
    required ResidenceChanges changes,
    ResidenceOverlapProposal? overlapConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteResidence({required String residenceId}) {
    throw UnimplementedError();
  }
}
