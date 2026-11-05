import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../data/fixtures/home_service_samples.dart';
import '../../domain/entities/home_service_details.dart';

final homeServiceDetailsProvider = Provider.autoDispose.family<HomeServiceDetails, String>(
  (ref, serviceId) => isSampleId(serviceId)
    ? homeServiceSamples[serviceId] ?? const HomeServiceDetails()
    : const HomeServiceDetails(),
);
