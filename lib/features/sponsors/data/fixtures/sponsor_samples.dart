import '../../domain/entities/sponsored_ad.dart';

List<SponsoredAd> sponsorSamples(String location) => [
  SponsoredAd(id: 'demo:ad-${location.toLowerCase()}-1', location: location,
    advertiser: location == 'Thrissur' ? 'Sample Heritage Stay' : 'Sample Café',
    title: location == 'Thrissur' ? 'Rest & stay near Swaraj Round' : 'Refresh before your journey',
    description: location == 'Thrissur' ? 'A calm stay near your next connection.'
      : 'Coffee and Kerala snacks near $location bus stand.',
    imageUrl: location == 'Thrissur' ? 'asset:hotel' : null),
  SponsoredAd(id: 'demo:ad-${location.toLowerCase()}-2', location: location,
    advertiser: 'Sample Local Store',
    title: 'Everyday essentials, close by',
    description: 'A local shopping stop near $location.'),
];
