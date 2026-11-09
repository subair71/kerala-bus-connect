import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Activated on the first place request, never on the application's cold start.
class FirebasePlacesClient {
  final String region, webSiteKey;
  Future<void>? _activation;
  FirebasePlacesClient({required this.region, required this.webSiteKey});

  Future<void> _activate() async {
    if (kIsWeb && webSiteKey.isEmpty) {
      throw StateError('Places App Check is not configured');
    }
    await FirebaseAppCheck.instance.activate(
      webProvider: kIsWeb ? ReCaptchaV3Provider(webSiteKey) : null,
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    );
  }

  Future<Object?> suggest(String input) => call('placeSuggestions', {'input': input});

  Future<Object?> call(String name, Map<String, Object?> data) async {
    try {
      await (_activation ??= _activate());
    } catch (_) {
      _activation = null;
      rethrow;
    }
    final result = await FirebaseFunctions.instanceFor(region: region)
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
        )
        .call<Object?>(data);
    return result.data;
  }
}
