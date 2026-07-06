import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:latlong2/latlong.dart';

enum DistributionMapScope {
  all,
  mine,
}

enum DistributionBasemap {
  defaultMap,
  satellite,
  topography,
}

enum DistributionVerificationFilter {
  all,
  verified,
  publicUnverified,
}

extension DistributionBasemapX on DistributionBasemap {
  String get label => switch (this) {
        DistributionBasemap.defaultMap => 'Default/Jalan',
        DistributionBasemap.satellite => 'Satelit',
        DistributionBasemap.topography => 'Topografi',
      };

  String get urlTemplate => switch (this) {
        DistributionBasemap.defaultMap =>
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        DistributionBasemap.satellite =>
          'https://server.arcgisonline.com/ArcGIS/rest/services/'
              'World_Imagery/MapServer/tile/{z}/{y}/{x}',
        DistributionBasemap.topography =>
          'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      };
}

extension DistributionVerificationFilterX on DistributionVerificationFilter {
  String get label => switch (this) {
        DistributionVerificationFilter.all => 'Semua',
        DistributionVerificationFilter.verified => 'Terverifikasi',
        DistributionVerificationFilter.publicUnverified => 'Temuan Publik',
      };
}

class DistributionMapFilter {
  final DistributionMapScope scope;
  final DistributionBasemap basemap;
  final DistributionVerificationFilter verificationFilter;
  final String? speciesId;
  final String? dateBucket;
  final bool verifiedOnly;

  const DistributionMapFilter({
    this.scope = DistributionMapScope.all,
    this.basemap = DistributionBasemap.defaultMap,
    this.verificationFilter = DistributionVerificationFilter.verified,
    this.speciesId,
    this.dateBucket,
    this.verifiedOnly = true,
  });

  bool get hasActiveFilters =>
      speciesId != null ||
      dateBucket != null ||
      verificationFilter != DistributionVerificationFilter.verified ||
      basemap != DistributionBasemap.defaultMap;

  DistributionMapFilter copyWith({
    DistributionMapScope? scope,
    DistributionBasemap? basemap,
    DistributionVerificationFilter? verificationFilter,
    String? speciesId,
    String? dateBucket,
    bool? verifiedOnly,
    bool clearSpeciesId = false,
    bool clearDateBucket = false,
  }) {
    return DistributionMapFilter(
      scope: scope ?? this.scope,
      basemap: basemap ?? this.basemap,
      verificationFilter: verificationFilter ??
          (verifiedOnly == null
              ? this.verificationFilter
              : verifiedOnly
                  ? DistributionVerificationFilter.verified
                  : DistributionVerificationFilter.all),
      speciesId: clearSpeciesId ? null : speciesId ?? this.speciesId,
      dateBucket: clearDateBucket ? null : dateBucket ?? this.dateBucket,
      verifiedOnly: verifiedOnly ??
          (verificationFilter == null
              ? this.verifiedOnly
              : verificationFilter == DistributionVerificationFilter.verified),
    );
  }
}

class DistributionMapPoint {
  final ClassificationRecord record;
  final LatLng point;
  final bool isPrecise;

  const DistributionMapPoint({
    required this.record,
    required this.point,
    required this.isPrecise,
  });
}

class DistributionCluster {
  final List<DistributionMapPoint> points;
  final LatLng center;

  const DistributionCluster({
    required this.points,
    required this.center,
  });

  bool get isSingle => points.length == 1;
  DistributionMapPoint get first => points.first;
}
