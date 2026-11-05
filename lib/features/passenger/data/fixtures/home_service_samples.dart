import '../../domain/entities/home_service_details.dart';

/// Display-only fictional fares for the existing, stable demo services.
/// These records are never written to Firebase or joined to real schedules.
const homeServiceSamples = <String, HomeServiceDetails>{
  'demo:service-antony': HomeServiceDetails(fareRupees: 38, fareLabel: 'Sample fare'),
  'demo:service-swift': HomeServiceDetails(fareRupees: 45, fareLabel: 'Sample fare'),
  'demo:service-greenline': HomeServiceDetails(fareRupees: 25, fareLabel: 'Sample fare'),
  'demo:service-fast': HomeServiceDetails(fareRupees: 60, fareLabel: 'Sample fare'),
  'demo:service-royal': HomeServiceDetails(fareRupees: 55, fareLabel: 'Sample fare'),
  'demo:service-minnal': HomeServiceDetails(fareRupees: 70, fareLabel: 'Sample fare'),
};
