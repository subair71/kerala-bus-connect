import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import {autocomplete, PlacesError} from './places.js';

const placesKey = defineSecret('GOOGLE_PLACES_API_KEY');

export const placeSuggestions = onCall({
  region: 'asia-south1',
  enforceAppCheck: true,
  secrets: [placesKey],
  cors: process.env.FUNCTIONS_EMULATOR === 'true' ? true : ['https://subair71.github.io'],
  timeoutSeconds: 10,
  memory: '256MiB',
  maxInstances: 2,
  concurrency: 20,
}, async request => {
  // App attestation protects public passenger search without requiring sign-in.
  if (!request.app) throw new HttpsError('unauthenticated', 'App verification required.');
  try {
    return await autocomplete(request.data, {apiKey: placesKey.value()});
  } catch (error) {
    if (error instanceof PlacesError) throw new HttpsError(error.code, error.message);
    throw new HttpsError('unavailable', 'Place suggestions are temporarily unavailable.');
  }
});

export {searchTimetables, findNearbyStops, managePlatform, listPlatformRecords,
  relevantAdvertisements, recordUsage, syncServiceDepartures,
  syncDailyDepartures, refreshAdvertisements} from './platform.js';
