class SponsoredAd {
  final String id, location, advertiser, title, description;
  final String? imageUrl, website;
  final bool active;
  const SponsoredAd({
    required this.id,
    required this.location,
    required this.advertiser,
    required this.title,
    required this.description,
    this.imageUrl,
    this.website,
    this.active = true,
  });
}

String sponsorLocation(String boarding) {
  final value = boarding.trim().toLowerCase();
  for (final city in [
    'Thrissur',
    'Aluva',
    'Kaloor',
    'Palakkad',
    'Guruvayur',
    'Kalamassery',
    'Edappally',
    'Fort Kochi',
    'Kakkanad',
  ]) {
    if (value.contains(city.toLowerCase())) return city;
  }
  return boarding.trim().isEmpty ? 'Kerala' : boarding.trim();
}
