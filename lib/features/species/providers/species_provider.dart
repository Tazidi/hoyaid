import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/models/label_map.dart';
import 'package:hoyaid/features/species/services/species_service.dart';

final speciesServiceProvider = Provider<SpeciesService>((ref) {
  return SpeciesService();
});

final activeSpeciesProvider = StreamProvider<List<HoyaSpecies>>((ref) {
  return ref.watch(speciesServiceProvider).watchActiveSpecies();
});

final allSpeciesProvider = StreamProvider<List<HoyaSpecies>>((ref) {
  return ref.watch(speciesServiceProvider).watchAllSpecies();
});

final speciesDetailProvider =
    StreamProvider.family<HoyaSpecies?, String>((ref, speciesId) {
  return ref.watch(speciesServiceProvider).watchSpecies(speciesId);
});

final labelMapProvider =
    StreamProvider.family<LabelMapModel?, String>((ref, modelVersion) {
  return ref.watch(speciesServiceProvider).watchLabelMap(modelVersion);
});
