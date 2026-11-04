import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB7h2kuVM8CvhNlkptsPtyKXXHUO4T1RQk',
  appId: '1:442982526142:web:6daaf45238e0cf8de442ef',
  messagingSenderId: '442982526142',
  projectId: 'findmybus-535ae',
  authDomain: 'findmybus-535ae.firebaseapp.com',
  storageBucket: 'findmybus-535ae.firebasestorage.app',
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const FindMyBus());
}
class FindMyBus extends StatelessWidget {
  const FindMyBus({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FindMyBus', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff087f80),
      scaffoldBackgroundColor: const Color(0xfff5f8fa)),
    home: const BusHome(),
  );
}
String timeLabel(int minutes) {
  final h = (minutes ~/ 60) % 24, m = minutes % 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}
int minutesNow() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}
class BusHome extends StatefulWidget {
  const BusHome({super.key});
  @override
  State<BusHome> createState() => _BusHomeState();
}
class _BusHomeState extends State<BusHome> {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final business = TextEditingController();
  final routeName = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  final stops = TextEditingController();
  final busName = TextEditingController();
  final searchFrom = TextEditingController();
  final searchTo = TextEditingController();
  TimeOfDay departure = const TimeOfDay(hour: 8, minute: 0);
  int tab = 0;
  String? selectedBusinessId, selectedRouteId;
  bool busy = false;
  @override
  void dispose() {
    for (final c in [business, routeName, from, to, stops, busName, searchFrom, searchTo]) { c.dispose(); }
    super.dispose();
  }
  void notice(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> perform(Future<void> Function() work) async {
    setState(() => busy = true);
    try { await work(); } on FirebaseException catch (e) {
      notice(e.message ?? e.code);
    } catch (e) { notice(e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> signIn(bool register, String email, String password) async {
    await perform(() async {
      if (register) {
        await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      } else {
        await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      }
      if (mounted) Navigator.of(context).pop();
    });
  }
  void loginDialog() {
    final email = TextEditingController(), password = TextEditingController();
    bool register = false;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, refresh) =>
      AlertDialog(title: Text(register ? 'Create owner account' : 'Owner login'),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Password (6+ characters)')),
          TextButton(onPressed: () => refresh(() => register = !register),
            child: Text(register ? 'Already registered? Sign in' : 'New business owner? Register')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => signIn(register, email.text, password.text),
            child: Text(register ? 'Register' : 'Sign in')),
        ])));
  }
  Widget panel(String title, Widget child) => Card(elevation: 0, color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        const SizedBox(height: 12), child,
      ])));
  Widget field(TextEditingController c, String label) => TextField(controller: c,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  Widget services() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: db.collection('services').where('published', isEqualTo: true).snapshots(),
    builder: (context, snap) {
      if (snap.hasError) return Text('Unable to load timetables: ${snap.error}');
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final a = searchFrom.text.trim().toLowerCase(), b = searchTo.text.trim().toLowerCase();
      final matches = snap.data!.docs.where((d) {
        final x = d.data();
        final stops = (x['stops'] as List<dynamic>? ?? []).map((s) => s.toString().toLowerCase()).toList();
        final i = a.isEmpty ? 0 : stops.indexOf(a);
        final j = b.isEmpty ? stops.length - 1 : stops.indexOf(b);
        return i >= 0 && j > i;
      }).toList();
      matches.sort((a, b) => ((a.data()['departureMinutes'] as num?)?.toInt() ?? 0)
        .compareTo((b.data()['departureMinutes'] as num?)?.toInt() ?? 0));
      final upcoming = matches.where((d) =>
        ((d.data()['departureMinutes'] as num?)?.toInt() ?? 0) >= minutesNow()).take(4).toList();
      Widget tile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final d = doc.data();
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.directions_bus)),
          title: Text(d['busName']?.toString() ?? 'Bus'),
          subtitle: Text('${d['businessName'] ?? ''} • ${(d['stops'] as List<dynamic>? ?? []).join(' → ')}'),
          trailing: Text(timeLabel((d['departureMinutes'] as num?)?.toInt() ?? 0),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        panel('Next ${upcoming.length} upcoming buses', upcoming.isEmpty
          ? const Text('No more scheduled departures today for this route.')
          : Column(children: upcoming.map(tile).toList())),
        panel('All matching services (${matches.length})', matches.isEmpty
          ? const Text('No published buses match this stop-to-stop search.')
          : Column(children: matches.map(tile).toList())),
        const Text('Scheduled departure times only. These are not live GPS arrival estimates.',
          style: TextStyle(color: Colors.black54, fontSize: 12)),
      ]);
    });
  Widget passenger() => Column(children: [
    panel('Search by boarding and destination stop', Column(children: [
      field(searchFrom, 'Boarding location / stop'), const SizedBox(height: 10),
      field(searchTo, 'Destination stop'), const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.search),
        label: const Text('Find buses')),
    ])),
    services(),
  ]);
  Widget owner() => StreamBuilder<User?>(
    stream: auth.authStateChanges(),
    builder: (context, snapshot) {
      final user = snapshot.data;
      if (user == null) return panel('Business owner access', Column(children: [
        const Text('Sign in or register to create a bus business, routes and timetables.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: loginDialog, child: const Text('Sign in / Register')),
      ]));
      return Column(children: [
        panel('Owner account', Row(children: [
          Expanded(child: Text(user.email ?? 'Signed in')),
          TextButton(onPressed: () => auth.signOut(), child: const Text('Sign out')),
        ])),
        panel('Create bus business', Column(children: [
          field(business, 'Business / operator name'), const SizedBox(height: 10),
          FilledButton.icon(onPressed: busy ? null : () => perform(() async {
            if (business.text.trim().isEmpty) throw Exception('Enter a business name');
            final ref = await db.collection('businesses').add({
              'ownerId': user.uid, 'name': business.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
            setState(() => selectedBusinessId = ref.id);
            business.clear(); notice('Business created');
          }), icon: const Icon(Icons.add_business), label: const Text('Create business')),
        ])),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('businesses').where('ownerId', isEqualTo: user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Business loading failed: ${snapshot.error}');
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final businesses = snapshot.data!.docs;
            if (businesses.isEmpty) return const Text('Create a business to add routes.');
            final selected = businesses.any((d) => d.id == selectedBusinessId)
              ? selectedBusinessId! : businesses.first.id;
            final operator = businesses.firstWhere((d) => d.id == selected);
            return Column(children: [
              panel('Manage business', DropdownButtonFormField<String>(
                value: selected, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Business', border: OutlineInputBorder()),
                items: businesses.map((d) => DropdownMenuItem(value: d.id,
                  child: Text(d.data()['name']?.toString() ?? 'Business'))).toList(),
                onChanged: (v) => setState(() { selectedBusinessId = v; selectedRouteId = null; }),
              )),
              panel('Create route', Column(children: [
                field(routeName, 'Route name'), const SizedBox(height: 10),
                field(from, 'Starting stop'), const SizedBox(height: 10),
                field(to, 'Last stop'), const SizedBox(height: 10),
                field(stops, 'Intermediate stops (comma separated)'), const SizedBox(height: 10),
                FilledButton.icon(onPressed: busy ? null : () => perform(() async {
                  final start = from.text.trim(), end = to.text.trim();
                  if (start.isEmpty || end.isEmpty || start.toLowerCase() == end.toLowerCase()) {
                    throw Exception('Enter different starting and ending stops');
                  }
                  final routeStops = [start, ...stops.text.split(',').map((s) => s.trim())
                    .where((s) => s.isNotEmpty), end];
                  final ref = await db.collection('routes').add({
                    'ownerId': user.uid, 'businessId': selected,
                    'businessName': operator.data()['name'], 'name': routeName.text.trim().isEmpty
                      ? '$start – $end' : routeName.text.trim(),
                    'stops': routeStops, 'createdAt': FieldValue.serverTimestamp(),
                  });
                  setState(() => selectedRouteId = ref.id);
                  routeName.clear(); from.clear(); to.clear(); stops.clear();
                  notice('Route created');
                }), icon: const Icon(Icons.alt_route), label: const Text('Save route')),
              ])),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection('routes').where('businessId', isEqualTo: selected).snapshots(),
                builder: (context, routesSnap) {
                  if (routesSnap.hasError) return Text('Routes loading failed: ${routesSnap.error}');
                  if (!routesSnap.hasData) return const CircularProgressIndicator();
                  final routes = routesSnap.data!.docs;
                  if (routes.isEmpty) return const Text('Create a route before adding departures.');
                  final selectedRoute = routes.any((d) => d.id == selectedRouteId)
                    ? selectedRouteId! : routes.first.id;
                  final route = routes.firstWhere((d) => d.id == selectedRoute);
                  return Column(children: [
                    panel('Publish bus timetable', Column(children: [
                      DropdownButtonFormField<String>(
                        value: selectedRoute, isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Route', border: OutlineInputBorder()),
                        items: routes.map((d) => DropdownMenuItem(value: d.id,
                          child: Text(d.data()['name']?.toString() ?? 'Route'))).toList(),
                        onChanged: (v) => setState(() => selectedRouteId = v)),
                      const SizedBox(height: 10),
                      field(busName, 'Bus name'), const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: () async {
                        final value = await showTimePicker(context: context, initialTime: departure);
                        if (value != null) setState(() => departure = value);
                      }, icon: const Icon(Icons.schedule),
                        label: Text('Departure: ${departure.format(context)}')),
                      const SizedBox(height: 10),
                      FilledButton.icon(onPressed: busy ? null : () => perform(() async {
                        if (busName.text.trim().isEmpty) throw Exception('Enter bus name');
                        await db.collection('services').add({
                          'ownerId': user.uid, 'businessId': selected, 'routeId': selectedRoute,
                          'businessName': operator.data()['name'], 'busName': busName.text.trim(),
                          'stops': route.data()['stops'],
                          'departureMinutes': departure.hour * 60 + departure.minute,
                          'published': true, 'createdAt': FieldValue.serverTimestamp(),
                        });
                        busName.clear(); notice('Timetable published to passenger search');
                      }), icon: const Icon(Icons.publish), label: const Text('Publish timetable')),
                    ])),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: db.collection('services').where('ownerId', isEqualTo: user.uid).snapshots(),
                      builder: (context, serviceSnap) {
                        if (!serviceSnap.hasData) return const SizedBox.shrink();
                        final mine = serviceSnap.data!.docs.where((d) =>
                          d.data()['businessId'] == selected).toList();
                        return panel('Your published buses (${mine.length})', Column(children:
                          mine.map((d) => ListTile(
                            title: Text(d.data()['busName']?.toString() ?? 'Bus'),
                            subtitle: Text(timeLabel((d.data()['departureMinutes'] as num).toInt())),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline),
                              onPressed: () => perform(() => d.reference.delete())),
                          )).toList()));
                      }),
                  ]);
                }),
            ]);
          }),
      ]);
    });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Row(children: [
      Icon(Icons.directions_bus, color: Color(0xff087f80)), SizedBox(width: 8), Text('FindMyBus'),
    ]), actions: [
      TextButton(onPressed: () => setState(() => tab = 0), child: const Text('Passengers')),
      TextButton(onPressed: () => setState(() => tab = 1), child: const Text('Bus owners')),
    ]),
    body: SingleChildScrollView(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xff102c49), Color(0xff078e91)])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tab == 0 ? 'Find your next bus' : 'Manage your bus business',
                style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tab == 0 ? 'Search published services by boarding stop and destination.'
                : 'Create businesses, routes, stops and scheduled departures.',
                style: const TextStyle(color: Colors.white70)),
            ])),
          const SizedBox(height: 14),
          if (tab == 0) passenger() else owner(),
        ])),
    ))),
  );
}
