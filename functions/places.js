export class PlacesError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

export function validateInput(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => key !== 'input') || typeof data.input !== 'string') {
    throw new PlacesError('invalid-argument', 'Enter a place name.');
  }
  const input = data.input.trim();
  if ([...input].length < 3 || input.length > 120 || /[\u0000-\u001f\u007f]/u.test(input)) {
    throw new PlacesError('invalid-argument', 'Enter between 3 and 120 characters.');
  }
  return input;
}

export async function autocomplete(data, {apiKey, fetchImpl = fetch}) {
  const input = validateInput(data);
  if (!apiKey) throw new PlacesError('failed-precondition', 'Places is not configured.');
  let response;
  try {
    response = await fetchImpl('https://places.googleapis.com/v1/places:autocomplete', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat',
      },
      body: JSON.stringify({
        input,
        includedRegionCodes: ['in'],
        languageCode: 'en',
        regionCode: 'in',
        // Bias towards Kerala without excluding cross-border destinations.
        locationBias: {rectangle: {
          low: {latitude: 8.1, longitude: 74.8},
          high: {latitude: 12.8, longitude: 77.5},
        }},
      }),
      signal: AbortSignal.timeout(4500),
    });
    if (!response.ok) {
      throw new PlacesError(
        response.status === 429 ? 'resource-exhausted' : 'unavailable',
        'Place suggestions are temporarily unavailable.',
      );
    }
    const result = await response.json();
    if (!Array.isArray(result.suggestions)) {
      // An empty Google response is a successful search with no predictions.
      if (result && typeof result === 'object' && Object.keys(result).length === 0) {
        return {suggestions: []};
      }
      throw new PlacesError('unavailable', 'Place suggestions are temporarily unavailable.');
    }
    return {suggestions: result.suggestions.slice(0, 5).flatMap(item => {
      const prediction = item?.placePrediction;
      const id = prediction?.placeId;
      const name = prediction?.structuredFormat?.mainText?.text;
      const address = prediction?.structuredFormat?.secondaryText?.text;
      if (typeof id !== 'string' || !id || typeof name !== 'string' || !name.trim()) return [];
      return [{id, name: name.trim(), address: typeof address === 'string' ? address : ''}];
    })};
  } catch (error) {
    if (error instanceof PlacesError) throw error;
    // Never forward upstream responses, keys, input or stack traces to clients.
    throw new PlacesError('unavailable', 'Place suggestions are temporarily unavailable.');
  }
}
