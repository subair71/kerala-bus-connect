class PlatformField {
  final String name, label, type;
  final String? collection;
  const PlatformField(
    this.name,
    this.label, {
    this.type = 'text',
    this.collection,
  });
}

class PlatformForm {
  final String action, title;
  final List<PlatformField> fields;
  const PlatformForm(this.action, this.title, this.fields);
}

const platformForms = <String, PlatformForm>{
  'registerAdvertiser':
      PlatformForm('registerAdvertiser', 'Register advertiser', [
        PlatformField('name', 'Business name'),
        PlatformField('category', 'Business category'),
        PlatformField('contact', 'Contact details'),
        PlatformField('district', 'District'),
        PlatformField('latitude', 'Business latitude', type: 'decimal'),
        PlatformField('longitude', 'Business longitude', type: 'decimal'),
      ]),
  'submitAd': PlatformForm('submitAd', 'Submit advertisement for approval', [
    PlatformField('advertiserId', 'Advertiser', collection: 'advertisers'),
    PlatformField(
      'packageId',
      'Advertising package',
      collection: 'advertising_packages',
    ),
    PlatformField('title', 'Advertisement title'),
    PlatformField('description', 'Description'),
    PlatformField('imageUrl', 'Advertisement image (HTTPS URL)'),
    PlatformField('website', 'Business website (optional)'),
    PlatformField('requestedStart', 'Start date (YYYY-MM-DD, optional)'),
    PlatformField('location', 'Business location'),
    PlatformField('district', 'District'),
    PlatformField('latitude', 'Business latitude', type: 'decimal'),
    PlatformField('longitude', 'Business longitude', type: 'decimal'),
    PlatformField('coverage', 'Coverage: nearby, route, or district'),
    PlatformField('radiusKm', 'Coverage radius in km', type: 'integer'),
    PlatformField(
      'routeIds',
      'Selected routes',
      type: 'list',
      collection: 'routes',
    ),
    PlatformField(
      'stopIds',
      'Selected stops',
      type: 'list',
      collection: 'stops',
    ),
  ]),
  'createOrder':
      PlatformForm('createOrder', 'Create payment or renewal order', [
        PlatformField('adId', 'Advertisement', collection: 'sponsored_ads'),
        PlatformField('workflow', 'Payment workflow', type: 'workflow'),
      ]),
  'submitReceipt': PlatformForm('submitReceipt', 'Submit payment receipt', [
    PlatformField(
      'orderId',
      'Advertising order',
      collection: 'advertising_orders',
    ),
    PlatformField('receipt', 'Receipt or transfer reference'),
  ]),
  'verifyPayment': PlatformForm('verifyPayment', 'Verify received payment', [
    PlatformField(
      'orderId',
      'Advertising order',
      collection: 'advertising_orders',
    ),
    PlatformField(
      'receivedPaise',
      'Amount actually received by FindMyBus (₹)',
      type: 'money',
    ),
    PlatformField('transactionReference', 'Verified bank / payment reference'),
  ]),
  'reviewAd': PlatformForm('reviewAd', 'Review advertisement', [
    PlatformField('adId', 'Advertisement', collection: 'sponsored_ads'),
    PlatformField('approval', 'Review decision', type: 'approval'),
    PlatformField('note', 'Review note'),
  ]),
  'cancelAd': PlatformForm('cancelAd', 'Suspend or reinstate advertisement', [
    PlatformField('adId', 'Advertisement', collection: 'sponsored_ads'),
    PlatformField('cancelled', 'Suspend advertisement', type: 'boolean'),
    PlatformField('note', 'Reason'),
  ]),
  'cancelOrder': PlatformForm('cancelOrder', 'Cancel unpaid order', [
    PlatformField(
      'orderId',
      'Advertising order',
      collection: 'advertising_orders',
    ),
  ]),
  'refundOrder': PlatformForm('refundOrder', 'Record completed refund', [
    PlatformField(
      'orderId',
      'Advertising order',
      collection: 'advertising_orders',
    ),
    PlatformField('reference', 'Completed refund reference'),
  ]),
  'recordPayout':
      PlatformForm('recordPayout', 'Record completed owner payout', [
        PlatformField(
          'commissionIds',
          'Payable commissions for one owner',
          type: 'list',
          collection: 'commissions',
        ),
        PlatformField('amountPaise', 'Amount paid to owner (₹)', type: 'money'),
        PlatformField('reference', 'Completed bank payout reference'),
      ]),
  'savePackage': PlatformForm('savePackage', 'Configure advertising package', [
    PlatformField('id', 'Package identifier'),
    PlatformField('name', 'Package name'),
    PlatformField('pricePaise', 'Price (₹)', type: 'money'),
    PlatformField('durationDays', 'Duration (days)', type: 'integer'),
    PlatformField('radiusKm', 'Maximum radius (km)', type: 'integer'),
    PlatformField('routeLimit', 'Maximum selected routes', type: 'integer'),
    PlatformField(
      'adLimit',
      'Maximum advertisements per advertiser',
      type: 'integer',
    ),
    PlatformField(
      'coverage',
      'Allowed coverage: nearby, route, district',
      type: 'list',
    ),
    PlatformField(
      'eligibleRouteIds',
      'Eligible routes (leave empty for all)',
      type: 'list',
      collection: 'routes',
    ),
    PlatformField('features', 'Package features'),
    PlatformField('enabled', 'Available for purchase', type: 'boolean'),
  ]),
  'configureCommission': PlatformForm(
    'configureCommission',
    'Configure recurring commission',
    [
      PlatformField(
        'basisPoints',
        'Commission (%) for new orders',
        type: 'money',
      ),
    ],
  ),
  'saveStop': PlatformForm('saveStop', 'Verify bus stop location', [
    PlatformField('id', 'Stop identifier'),
    PlatformField('name', 'Stop name'),
    PlatformField('district', 'District'),
    PlatformField('latitude', 'Verified latitude', type: 'decimal'),
    PlatformField('longitude', 'Verified longitude', type: 'decimal'),
    PlatformField(
      'routeIds',
      'Routes serving this stop',
      type: 'list',
      collection: 'routes',
    ),
    PlatformField('active', 'Stop active', type: 'boolean'),
  ]),
  'ownerAccess': PlatformForm('ownerAccess', 'Manage owner access', [
    PlatformField('ownerId', 'Owner account ID'),
    PlatformField('disabled', 'Suspend owner', type: 'boolean'),
    PlatformField('note', 'Reason'),
  ]),
  'changeAttribution':
      PlatformForm('changeAttribution', 'Change referring owner', [
        PlatformField('advertiserId', 'Advertiser', collection: 'advertisers'),
        PlatformField('ownerId', 'New referring owner account ID'),
        PlatformField('note', 'Reason'),
      ]),
  'reviewSchedule': PlatformForm('reviewSchedule', 'Verify timetable', [
    PlatformField('id', 'Trip', collection: 'services'),
    PlatformField('verification', 'Verification result'),
    PlatformField('note', 'Review note'),
  ]),
  'reviewReport': PlatformForm('reviewReport', 'Review timing report', [
    PlatformField('id', 'Timing report', collection: 'schedule_reports'),
    PlatformField('verification', 'Review result'),
    PlatformField('note', 'Review note'),
  ]),
  'reportSchedule': PlatformForm('reportSchedule', 'Report incorrect timing', [
    PlatformField('tripId', 'Trip identifier'),
    PlatformField('message', 'What timing needs correcting?'),
  ]),
};
