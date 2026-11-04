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

const weekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String todayName() {
  final now = DateTime.now();
  return weekDays[now.weekday - 1];
}

String timeLabel(int minutes) {
  final h = (minutes ~/ 60) % 24, m = minutes % 60;
  final displayH = h % 12 == 0 ? 12 : h % 12;
  final period = h < 12 ? 'AM' : 'PM';
  return '$displayH:${m.toString().padLeft(2, '0')} $period';
}

int minutesNow() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const FindMyBus());
}

class FindMyBus extends StatelessWidget {
  const FindMyBus({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FindMyBus',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xff087f80),
          scaffoldBackgroundColor: const Color(0xfff5f8fa),
        ),
        home: const BusHome(),
      );
}

class BusHome extends StatefulWidget {
  const BusHome({super.key});

  @override
  State<BusHome> createState() => _BusHomeState();
}

class _BusHomeState extends State<BusHome> {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  // Controllers for Business & Route creation/editing
  final business = TextEditingController();
  final routeName = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  final stops = TextEditingController();
  bool createReturnRouteToo = true;
  String? editingRouteId;

  // Controllers for Publishing/Editing Timetable
  final busName = TextEditingController();
  final offTimingsNote = TextEditingController();
  TimeOfDay departure = const TimeOfDay(hour: 8, minute: 0);
  bool customizeStopTimings = false;
  final Map<String, TimeOfDay> stopTimeValues = {};
  final Set<String> selectedOffDays = {};
  String? editingServiceId;

  // Controllers for Passenger Search
  final searchFrom = TextEditingController();
  final searchTo = TextEditingController();
  String filterDay = 'All Days';
  bool onlyRunningToday = false;

  int tab = 0;
  String? selectedBusinessId, selectedRouteId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    filterDay = todayName();
  }

  @override
  void dispose() {
    for (final c in [
      business,
      routeName,
      from,
      to,
      stops,
      busName,
      offTimingsNote,
      searchFrom,
      searchTo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void notice(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xff087f80),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> perform(Future<void> Function() work) async {
    setState(() => busy = true);
    try {
      await work();
    } on FirebaseException catch (e) {
      notice(e.message ?? e.code, isError: true);
    } catch (e) {
      notice(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signIn(bool register, String email, String password) async {
    await perform(() async {
      if (register) {
        await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
      if (mounted) Navigator.of(context).pop();
    });
  }

  void loginDialog() {
    final email = TextEditingController(), password = TextEditingController();
    bool register = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(register ? 'Create owner account' : 'Owner login'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (6+ characters)',
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => refresh(() => register = !register),
                  child: Text(
                    register
                        ? 'Already registered? Sign in'
                        : 'New business owner? Register',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => signIn(register, email.text, password.text),
              child: Text(register ? 'Register' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  void cancelRouteEdit() {
    setState(() {
      editingRouteId = null;
      routeName.clear();
      from.clear();
      to.clear();
      stops.clear();
      createReturnRouteToo = true;
    });
  }

  void cancelServiceEdit() {
    setState(() {
      editingServiceId = null;
      busName.clear();
      offTimingsNote.clear();
      selectedOffDays.clear();
      customizeStopTimings = false;
      stopTimeValues.clear();
      departure = const TimeOfDay(hour: 8, minute: 0);
    });
  }

  Widget panel(String title, Widget child, {Widget? action}) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (action != null) action,
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );

  Widget field(
    TextEditingController c,
    String label, {
    String? hint,
    int maxLines = 1,
  }) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  // --- PASSENGER UI ---

  Widget passenger() => Column(
        children: [
          panel(
            'Search Buses & Timetables',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          field(
                            searchFrom,
                            'Boarding location / stop',
                            hint: 'e.g. Kozhikode',
                          ),
                          const SizedBox(height: 10),
                          field(
                            searchTo,
                            'Destination stop',
                            hint: 'e.g. Kannur',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Swap stops (Check return buses)',
                      icon: const Icon(Icons.swap_vert, size: 28),
                      onPressed: () {
                        setState(() {
                          final temp = searchFrom.text;
                          searchFrom.text = searchTo.text;
                          searchTo.text = temp;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Filter by Day:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    DropdownButton<String>(
                      value: filterDay,
                      isDense: true,
                      items: ['All Days', ...weekDays].map((day) {
                        return DropdownMenuItem(
                          value: day,
                          child: Text(
                            day == todayName() ? '$day (Today)' : day,
                            style: TextStyle(
                              fontWeight: day == todayName()
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: day == todayName()
                                  ? const Color(0xff087f80)
                                  : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => filterDay = v);
                      },
                    ),
                    FilterChip(
                      selected: onlyRunningToday,
                      label: Text(
                        'Running on ${filterDay == 'All Days' ? todayName() : filterDay}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onSelected: (selected) {
                        setState(() => onlyRunningToday = selected);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.search),
                  label: const Text('Find buses'),
                ),
              ],
            ),
          ),
          services(),
        ],
      );

  Widget services() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('services')
            .where('published', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Text('Unable to load timetables: ${snap.error}');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final a = searchFrom.text.trim().toLowerCase();
          final b = searchTo.text.trim().toLowerCase();
          final effectiveDay =
              filterDay == 'All Days' ? todayName() : filterDay;

          final allDocs = snap.data!.docs;

          // Filter matching stops
          final matches = allDocs.where((d) {
            final x = d.data();
            final stopsList = (x['stops'] as List<dynamic>? ?? [])
                .map((s) => s.toString().toLowerCase())
                .toList();

            final i = a.isEmpty ? 0 : stopsList.indexOf(a);
            final j = b.isEmpty ? stopsList.length - 1 : stopsList.indexOf(b);

            if (i < 0 || j <= i) return false;

            if (onlyRunningToday) {
              final offDays = (x['offDays'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();
              if (offDays.contains(effectiveDay)) return false;
            }

            return true;
          }).toList();

          // Sort by effective boarding time (or departure time)
          matches.sort((docA, docB) {
            final dataA = docA.data();
            final dataB = docB.data();

            final timeA = getBoardingTime(dataA, a);
            final timeB = getBoardingTime(dataB, a);

            return timeA.compareTo(timeB);
          });

          final currentMinutes = minutesNow();
          final isLookingAtToday = (effectiveDay == todayName());

          final upcoming = matches.where((d) {
            if (!isLookingAtToday) return true;
            final data = d.data();
            final offDays = (data['offDays'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
            if (offDays.contains(effectiveDay)) return false;

            final time = getBoardingTime(data, a);
            return time >= currentMinutes;
          }).take(4).toList();

          Widget busCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final d = doc.data();
            final stopsList = (d['stops'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
            final offDays = (d['offDays'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
            final offTimings = d['offTimingsNote']?.toString();
            final isOffOnSelectedDay = offDays.contains(effectiveDay);

            final boardTime = getBoardingTime(d, a);
            final destTime =
                getDestinationTime(d, b, fallback: boardTime + 30);
            final hasCustomTimings = d['stopTimings'] is Map;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isOffOnSelectedDay
                      ? Colors.orange.shade200
                      : Colors.teal.shade100,
                ),
              ),
              color:
                  isOffOnSelectedDay ? const Color(0xfffff9f5) : Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openTrainRouteSheet(d, a, b, effectiveDay),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: isOffOnSelectedDay
                                ? Colors.orange.shade100
                                : const Color(0xffe0f2f1),
                            foregroundColor: isOffOnSelectedDay
                                ? Colors.deepOrange
                                : const Color(0xff087f80),
                            child: const Icon(Icons.directions_bus),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['busName']?.toString() ?? 'Bus',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${d['businessName'] ?? 'Operator'} • ${d['routeName'] ?? stopsList.join(' → ')}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeLabel(boardTime),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xff087f80),
                                ),
                              ),
                              if (destTime > boardTime)
                                Text(
                                  'Arr: ${timeLabel(destTime)} (${destTime - boardTime}m)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Stops: ${stopsList.join(' → ')}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                      if (hasCustomTimings) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: stopsList.map((stop) {
                            final stopTimings =
                                d['stopTimings'] as Map<String, dynamic>?;
                            final stopMinutes = stopTimings?[stop];
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              label: Text(
                                stopMinutes != null
                                    ? '$stop: ${timeLabel((stopMinutes as num).toInt())}'
                                    : stop,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (offDays.isNotEmpty ||
                          (offTimings != null && offTimings.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (offDays.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isOffOnSelectedDay
                                      ? Colors.red.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOffOnSelectedDay
                                        ? Colors.red.shade300
                                        : Colors.orange.shade300,
                                  ),
                                ),
                                child: Text(
                                  isOffOnSelectedDay
                                      ? '⚠️ No service on $effectiveDay (Off: ${offDays.join(', ')})'
                                      : 'Off Days: ${offDays.join(', ')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isOffOnSelectedDay
                                        ? Colors.red.shade900
                                        : Colors.brown.shade800,
                                  ),
                                ),
                              ),
                            if (offTimings != null && offTimings.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ℹ️ Note: $offTimings',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.route,
                              size: 15, color: Color(0xff087f80)),
                          const SizedBox(width: 6),
                          const Text(
                            'Click to view train-style route & stop schedule',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff087f80),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'View Timeline',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size: 11, color: Colors.grey.shade500),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              panel(
                isLookingAtToday
                    ? 'Upcoming departures today (${upcoming.length})'
                    : 'Departures for $effectiveDay (${matches.length})',
                upcoming.isEmpty
                    ? Text(
                        isLookingAtToday
                            ? 'No more scheduled departures today for this route.'
                            : 'No published departures match this search.',
                      )
                    : Column(children: upcoming.map(busCard).toList()),
              ),
              panel(
                'All matching route services (${matches.length})',
                matches.isEmpty
                    ? const Text(
                        'No published buses match this stop-to-stop search.')
                    : Column(children: matches.map(busCard).toList()),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Scheduled timings published by bus operators. Subject to traffic & operating conditions.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      );

  int getBoardingTime(Map<String, dynamic> data, String queryFrom) {
    if (data['stopTimings'] is Map && queryFrom.isNotEmpty) {
      final map = data['stopTimings'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == queryFrom) {
          return (entry.value as num?)?.toInt() ?? 0;
        }
      }
    }
    return (data['departureMinutes'] as num?)?.toInt() ?? 0;
  }

  int getDestinationTime(
    Map<String, dynamic> data,
    String queryTo, {
    required int fallback,
  }) {
    if (data['stopTimings'] is Map && queryTo.isNotEmpty) {
      final map = data['stopTimings'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == queryTo) {
          return (entry.value as num?)?.toInt() ?? fallback;
        }
      }
    }
    return fallback;
  }

  // --- OWNER UI ---

  Widget owner() => StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return panel(
              'Business owner access',
              Column(
                children: [
                  const Text(
                    'Sign in or register to manage bus businesses, multiple routes, return trips, stop timings, and edit timetables.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: loginDialog,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in / Register as Owner'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              panel(
                'Owner Account',
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in as:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            user.email ?? 'Owner',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => auth.signOut(),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
              panel(
                'Create Bus Operator Business',
                Column(
                  children: [
                    field(
                      business,
                      'Business / Operator Name',
                      hint: 'e.g. Malabar Travels, Royal Bus Service',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => perform(() async {
                                final name = business.text.trim();
                                if (name.isEmpty) {
                                  throw Exception('Enter a business name');
                                }
                                final ref =
                                    await db.collection('businesses').add({
                                  'ownerId': user.uid,
                                  'name': name,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                setState(() => selectedBusinessId = ref.id);
                                business.clear();
                                notice('Business created successfully');
                              }),
                      icon: const Icon(Icons.add_business),
                      label: const Text('Create Business'),
                    ),
                  ],
                ),
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('businesses')
                    .where('ownerId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Business loading failed: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final businesses = snapshot.data!.docs;
                  if (businesses.isEmpty) {
                    return panel(
                      'No Businesses Found',
                      const Text(
                        'Create your bus business above to start managing routes and timetables.',
                      ),
                    );
                  }

                  final selected =
                      businesses.any((d) => d.id == selectedBusinessId)
                          ? selectedBusinessId!
                          : businesses.first.id;
                  final operator =
                      businesses.firstWhere((d) => d.id == selected);

                  return Column(
                    children: [
                      panel(
                        'Active Business Operator',
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selected,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Selected Business',
                                  border: OutlineInputBorder(),
                                ),
                                items: businesses
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d.id,
                                        child: Text(
                                          d.data()['name']?.toString() ??
                                              'Business',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  selectedBusinessId = v;
                                  selectedRouteId = null;
                                  cancelRouteEdit();
                                  cancelServiceEdit();
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Edit Business Name',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                final editCtrl = TextEditingController(
                                  text: operator.data()['name']?.toString() ??
                                      '',
                                );
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Edit Business Name'),
                                    content: TextField(
                                      controller: editCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Business Name',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => perform(() async {
                                          final newN = editCtrl.text.trim();
                                          if (newN.isEmpty) {
                                            throw Exception(
                                                'Enter business name');
                                          }
                                          await operator.reference.update({
                                            'name': newN,
                                            'ownerId': user.uid,
                                          });
                                          Navigator.pop(ctx);
                                          notice('Business name updated');
                                        }),
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ownerRoutesSection(user, selected, operator),
                    ],
                  );
                },
              ),
            ],
          );
        },
      );

  Widget ownerRoutesSection(
    User user,
    String businessId,
    QueryDocumentSnapshot<Map<String, dynamic>> operatorDoc,
  ) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('routes')
            .where('businessId', isEqualTo: businessId)
            .snapshots(),
        builder: (context, routesSnap) {
          if (routesSnap.hasError) {
            return Text('Routes loading failed: ${routesSnap.error}');
          }
          if (!routesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = routesSnap.data!.docs;
          final isEditingThisRoute = editingRouteId != null;

          return Column(
            children: [
              panel(
                isEditingThisRoute
                    ? 'Edit Route'
                    : 'Add Route & Optional Return Route',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEditingThisRoute)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.edit,
                                size: 16, color: Color(0xff087f80)),
                            const SizedBox(width: 6),
                            const Text(
                              'Editing existing route. Updates will sync to existing timetables.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff087f80),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: cancelRouteEdit,
                              child: const Text('Cancel Edit'),
                            ),
                          ],
                        ),
                      ),
                    field(
                      routeName,
                      'Route Name (optional)',
                      hint: 'e.g. Kozhikode - Kannur Express',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            from,
                            'Starting stop',
                            hint: 'e.g. Kozhikode',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: field(to, 'Last stop', hint: 'e.g. Kannur'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    field(
                      stops,
                      'Intermediate stops (comma-separated)',
                      hint: 'e.g. Koyilandy, Vadakara, Thalassery',
                    ),
                    const SizedBox(height: 8),
                    if (!isEditingThisRoute)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Automatically generate return route (reversed stops)',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'Creates both outbound and return directions simultaneously.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: createReturnRouteToo,
                        onChanged: (v) =>
                            setState(() => createReturnRouteToo = v),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => perform(() async {
                                      final start = from.text.trim();
                                      final end = to.text.trim();
                                      if (start.isEmpty ||
                                          end.isEmpty ||
                                          start.toLowerCase() ==
                                              end.toLowerCase()) {
                                        throw Exception(
                                          'Enter distinct starting and ending stops',
                                        );
                                      }

                                      final intermediate = stops.text
                                          .split(',')
                                          .map((s) => s.trim())
                                          .where((s) => s.isNotEmpty)
                                          .toList();

                                      final forwardStops = [
                                        start,
                                        ...intermediate,
                                        end,
                                      ];
                                      final mainName =
                                          routeName.text.trim().isEmpty
                                              ? '$start → $end'
                                              : routeName.text.trim();

                                      if (isEditingThisRoute) {
                                        // Update existing route
                                        await db
                                            .collection('routes')
                                            .doc(editingRouteId)
                                            .update({
                                          'ownerId': user.uid,
                                          'name': mainName,
                                          'startStop': start,
                                          'endStop': end,
                                          'stops': forwardStops,
                                        });

                                        // Sync route stops and name in existing services using this route
                                        final relatedServices = await db
                                            .collection('services')
                                            .where('routeId',
                                                isEqualTo: editingRouteId)
                                            .get();
                                        for (final sDoc
                                            in relatedServices.docs) {
                                          await sDoc.reference.update({
                                            'routeName': mainName,
                                            'stops': forwardStops,
                                            'ownerId': user.uid,
                                          });
                                        }

                                        cancelRouteEdit();
                                        notice('Route updated successfully!');
                                      } else {
                                        // Create new route(s)
                                        final ref = await db
                                            .collection('routes')
                                            .add({
                                          'ownerId': user.uid,
                                          'businessId': businessId,
                                          'businessName':
                                              operatorDoc.data()['name'],
                                          'name': mainName,
                                          'startStop': start,
                                          'endStop': end,
                                          'stops': forwardStops,
                                          'isReturn': false,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                        setState(() =>
                                            selectedRouteId = ref.id);

                                        if (createReturnRouteToo) {
                                          final returnStops =
                                              forwardStops.reversed.toList();
                                          final returnName =
                                              '$end → $start (Return)';
                                          await db.collection('routes').add({
                                            'ownerId': user.uid,
                                            'businessId': businessId,
                                            'businessName':
                                                operatorDoc.data()['name'],
                                            'name': returnName,
                                            'startStop': end,
                                            'endStop': start,
                                            'stops': returnStops,
                                            'isReturn': true,
                                            'returnOfRouteId': ref.id,
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                        }

                                        routeName.clear();
                                        from.clear();
                                        to.clear();
                                        stops.clear();
                                        notice(
                                          createReturnRouteToo
                                              ? 'Main and return routes created!'
                                              : 'Route created!',
                                        );
                                      }
                                    }),
                            icon: Icon(
                                isEditingThisRoute ? Icons.save : Icons.alt_route),
                            label: Text(
                              isEditingThisRoute
                                  ? 'Save Route Changes'
                                  : (createReturnRouteToo
                                      ? 'Save Outbound & Return Routes'
                                      : 'Save Route'),
                            ),
                          ),
                        ),
                        if (isEditingThisRoute) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: cancelRouteEdit,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Existing Routes Manager
              if (routes.isNotEmpty)
                panel(
                  'Manage Routes (${routes.length})',
                  Column(
                    children: routes.map((doc) {
                      final r = doc.data();
                      final stopsList = (r['stops'] as List<dynamic>? ?? [])
                          .map((e) => e.toString())
                          .toList();
                      final isSelected = doc.id == selectedRouteId;
                      final isBeingEdited = doc.id == editingRouteId;
                      final isReturn = r['isReturn'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isBeingEdited
                                ? Colors.orange
                                : (isSelected
                                    ? const Color(0xff087f80)
                                    : Colors.grey.shade300),
                            width: (isBeingEdited || isSelected) ? 2 : 1,
                          ),
                          color: isBeingEdited
                              ? Colors.orange.shade50.withValues(alpha: 0.5)
                              : (isSelected
                                  ? const Color(0xffe0f2f1)
                                      .withValues(alpha: 0.4)
                                  : Colors.white),
                        ),
                        child: ListTile(
                          title: Text(
                            r['name']?.toString() ?? 'Route',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${stopsList.join(' → ')} (${stopsList.length} stops)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          leading: Icon(
                            isReturn ? Icons.keyboard_return : Icons.route,
                            color: isReturn
                                ? Colors.deepOrange
                                : const Color(0xff087f80),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit this route',
                                icon: const Icon(Icons.edit_outlined,
                                    color: Color(0xff087f80)),
                                onPressed: () {
                                  setState(() {
                                    editingRouteId = doc.id;
                                    routeName.text = r['name'] ?? '';
                                    from.text = r['startStop'] ??
                                        (stopsList.isNotEmpty
                                            ? stopsList.first
                                            : '');
                                    to.text = r['endStop'] ??
                                        (stopsList.isNotEmpty
                                            ? stopsList.last
                                            : '');
                                    stops.text = stopsList.length > 2
                                        ? stopsList
                                            .sublist(
                                                1, stopsList.length - 1)
                                            .join(', ')
                                        : '';
                                  });
                                  notice('Editing route: ${r['name']}');
                                },
                              ),
                              if (!isReturn &&
                                  !routes.any(
                                    (other) =>
                                        other.data()['returnOfRouteId'] ==
                                        doc.id,
                                  ))
                                IconButton(
                                  tooltip: 'Generate return route',
                                  icon: const Icon(
                                    Icons.swap_calls,
                                    color: Colors.deepOrange,
                                  ),
                                  onPressed: () => perform(() async {
                                    final revStops =
                                        stopsList.reversed.toList();
                                    await db.collection('routes').add({
                                      'ownerId': user.uid,
                                      'businessId': businessId,
                                      'businessName':
                                          operatorDoc.data()['name'],
                                      'name':
                                          '${revStops.first} → ${revStops.last} (Return)',
                                      'startStop': revStops.first,
                                      'endStop': revStops.last,
                                      'stops': revStops,
                                      'isReturn': true,
                                      'returnOfRouteId': doc.id,
                                      'createdAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                    notice('Return route generated!');
                                  }),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => perform(() async {
                                  await doc.reference.delete();
                                  if (selectedRouteId == doc.id) {
                                    setState(() => selectedRouteId = null);
                                  }
                                  if (editingRouteId == doc.id) {
                                    cancelRouteEdit();
                                  }
                                  notice('Route deleted');
                                }),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              selectedRouteId = doc.id;
                              initStopTimings(stopsList);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Timetable Publisher & Editor Section
              ownerTimetablePublishSection(
                user,
                businessId,
                operatorDoc,
                routes,
              ),
            ],
          );
        },
      );

  void initStopTimings(List<String> stopsList) {
    stopTimeValues.clear();
    int currentM = departure.hour * 60 + departure.minute;
    for (int i = 0; i < stopsList.length; i++) {
      final h = (currentM ~/ 60) % 24;
      final m = currentM % 60;
      stopTimeValues[stopsList[i]] = TimeOfDay(hour: h, minute: m);
      currentM += 15;
    }
  }

  Widget ownerTimetablePublishSection(
    User user,
    String businessId,
    QueryDocumentSnapshot<Map<String, dynamic>> operatorDoc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> routes,
  ) {
    if (routes.isEmpty) {
      return panel(
        'Publish Bus Timetable',
        const Text('Create at least one route above before adding timetables.'),
      );
    }

    final selectedRoute = routes.any((d) => d.id == selectedRouteId)
        ? selectedRouteId!
        : routes.first.id;
    final routeDoc = routes.firstWhere((d) => d.id == selectedRoute);
    final routeData = routeDoc.data();
    final routeStops = (routeData['stops'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    if (stopTimeValues.isEmpty || stopTimeValues.length != routeStops.length) {
      initStopTimings(routeStops);
    }

    final isEditingService = editingServiceId != null;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('services')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, serviceSnap) {
        final existingServices = serviceSnap.data?.docs ?? [];
        final businessServices = existingServices
            .where((d) => d.data()['businessId'] == businessId)
            .toList();

        return Column(
          children: [
            panel(
              isEditingService
                  ? 'Edit Published Timetable'
                  : 'Publish Bus Timetable & Service Days',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isEditingService)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.edit,
                              size: 16, color: Color(0xff087f80)),
                          const SizedBox(width: 6),
                          const Text(
                            'Updating existing bus timetable.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff087f80),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: cancelServiceEdit,
                            child: const Text('Cancel Edit'),
                          ),
                        ],
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    value: selectedRoute,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Route',
                      border: OutlineInputBorder(),
                    ),
                    items: routes.map((d) {
                      final rd = d.data();
                      final isRet = rd['isReturn'] == true;
                      return DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          '${rd['name'] ?? 'Route'}${isRet ? ' (Return Trip)' : ''}',
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedRouteId = v;
                        final newRoute =
                            routes.firstWhere((d) => d.id == v).data();
                        final newStops =
                            (newRoute['stops'] as List<dynamic>? ?? [])
                                .map((e) => e.toString())
                                .toList();
                        initStopTimings(newStops);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  field(
                    busName,
                    'Bus Name / Vehicle Registration',
                    hint: 'e.g. Malabar King (KL-11-AB-1234)',
                  ),
                  const SizedBox(height: 12),

                  // Starting Departure Time
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showTimePicker(
                              context: context,
                              initialTime: departure,
                            );
                            if (value != null) {
                              setState(() {
                                departure = value;
                                initStopTimings(routeStops);
                              });
                            }
                          },
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            'Departure from ${routeStops.first}: ${departure.format(context)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Individual Stop Timings (Optional)
                  ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    title: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Optional: Set Each Stop Timing',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Checkbox(
                          value: customizeStopTimings,
                          onChanged: (v) {
                            setState(
                                () => customizeStopTimings = v ?? false);
                          },
                        ),
                      ],
                    ),
                    subtitle: Text(
                      customizeStopTimings
                          ? 'Specific timings enabled for all ${routeStops.length} stops.'
                          : 'Tap to configure custom arrival timings for every stop.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: routeStops.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final stopName = entry.value;
                            final currentStopT = stopTimeValues[stopName] ??
                                TimeOfDay(
                                  hour: departure.hour,
                                  minute: (departure.minute + idx * 15) % 60,
                                );

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xff087f80),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      stopName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.access_time,
                                        size: 16),
                                    label: Text(
                                      currentStopT.format(context),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: currentStopT,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          customizeStopTimings = true;
                                          stopTimeValues[stopName] = picked;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Non-Service Days (Off Days)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event_busy,
                                size: 18, color: Colors.deepOrange),
                            SizedBox(width: 8),
                            Text(
                              'Non-service Days (Off Days)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select any day(s) when this bus does NOT operate:',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: weekDays.map((day) {
                            final isOff = selectedOffDays.contains(day);
                            return FilterChip(
                              label: Text(day),
                              selected: isOff,
                              selectedColor: Colors.deepOrange.shade100,
                              checkmarkColor: Colors.deepOrange,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedOffDays.add(day);
                                  } else {
                                    selectedOffDays.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Not-service timings / Blackout notes
                  field(
                    offTimingsNote,
                    'Non-service timings / Schedule notes (Optional)',
                    hint:
                        'e.g. No service 1:00 PM - 2:00 PM; off on Hartal days',
                  ),
                  const SizedBox(height: 14),

                  // Publish / Update Timetable with CONFLICT DETECTION (Only same vehicle conflicts)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => perform(() async {
                                    final name = busName.text.trim();
                                    if (name.isEmpty) {
                                      throw Exception('Enter bus name');
                                    }

                                    final depMinutes = departure.hour * 60 +
                                        departure.minute;

                                    // --- CONFLICT DETECTION ---
                                    // Different buses CAN depart at the same time.
                                    // Conflict ONLY occurs if the SAME bus vehicle is scheduled
                                    // for overlapping trips within 30 minutes.
                                    for (final existing in businessServices) {
                                      if (existing.id == editingServiceId) {
                                        continue; // Don't conflict with itself when editing
                                      }

                                      final edata = existing.data();
                                      final existingBus = edata['busName']
                                          ?.toString()
                                          .toLowerCase();
                                      final existingDep =
                                          (edata['departureMinutes'] as num?)
                                                  ?.toInt() ??
                                              0;
                                      final existingRouteName =
                                          edata['routeName'] ??
                                              'another route';

                                      if (existingBus ==
                                          name.toLowerCase()) {
                                        final diff =
                                            (depMinutes - existingDep).abs();
                                        if (diff < 30) {
                                          throw Exception(
                                            'Vehicle Conflict: The same bus "$name" already has a departure at ${timeLabel(existingDep)} on $existingRouteName. The same bus cannot depart two trips within 30 minutes. (Different buses are allowed at the same time).',
                                          );
                                        }
                                      }
                                    }

                                    // Prepare stop timings map
                                    final Map<String, int> finalStopTimings =
                                        {};
                                    if (customizeStopTimings) {
                                      for (final stop in routeStops) {
                                        final t =
                                            stopTimeValues[stop] ?? departure;
                                        finalStopTimings[stop] =
                                            t.hour * 60 + t.minute;
                                      }
                                    } else {
                                      int m = depMinutes;
                                      for (final stop in routeStops) {
                                        finalStopTimings[stop] = m;
                                        m += 15;
                                      }
                                    }

                                    final servicePayload = {
                                      'ownerId': user.uid,
                                      'businessId': businessId,
                                      'routeId': selectedRoute,
                                      'businessName':
                                          operatorDoc.data()['name'],
                                      'routeName': routeData['name'],
                                      'busName': name,
                                      'stops': routeStops,
                                      'departureMinutes': depMinutes,
                                      'stopTimings': finalStopTimings,
                                      'offDays': selectedOffDays.toList(),
                                      'offTimingsNote':
                                          offTimingsNote.text.trim(),
                                      'published': true,
                                    };

                                    if (isEditingService) {
                                      await db
                                          .collection('services')
                                          .doc(editingServiceId)
                                          .update(servicePayload);
                                      cancelServiceEdit();
                                      notice(
                                          'Timetable updated successfully!');
                                    } else {
                                      await db.collection('services').add({
                                        ...servicePayload,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                      cancelServiceEdit();
                                      notice(
                                          'Timetable published successfully!');
                                    }
                                  }),
                          icon: Icon(isEditingService
                              ? Icons.save
                              : Icons.publish),
                          label: Text(isEditingService
                              ? 'Update Timetable'
                              : 'Publish Timetable'),
                        ),
                      ),
                      if (isEditingService) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: cancelServiceEdit,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Published Timetables List with Edit & Delete options
            panel(
              'Your Published Bus Timetables (${businessServices.length})',
              businessServices.isEmpty
                  ? const Text(
                      'No timetables published yet for this business.')
                  : Column(
                      children: businessServices.map((d) {
                        final data = d.data();
                        final depM =
                            (data['departureMinutes'] as num?)?.toInt() ?? 0;
                        final stopsList =
                            (data['stops'] as List<dynamic>? ?? [])
                                .map((e) => e.toString())
                                .toList();
                        final offDays =
                            (data['offDays'] as List<dynamic>? ?? [])
                                .map((e) => e.toString())
                                .toList();
                        final note = data['offTimingsNote']?.toString();
                        final isEditingThisDoc = editingServiceId == d.id;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isEditingThisDoc
                                  ? Colors.orange
                                  : Colors.grey.shade200,
                              width: isEditingThisDoc ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: isEditingThisDoc
                                ? Colors.orange.shade50.withValues(alpha: 0.5)
                                : Colors.white,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isEditingThisDoc
                                  ? Colors.orange
                                  : const Color(0xff087f80),
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.schedule),
                            ),
                            title: Text(
                              '${data['busName'] ?? 'Bus'} • ${timeLabel(depM)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Route: ${data['routeName'] ?? stopsList.join(' → ')}',
                                ),
                                if (offDays.isNotEmpty)
                                  Text(
                                    'Off: ${offDays.join(', ')}',
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 11,
                                    ),
                                  ),
                                if (note != null && note.isNotEmpty)
                                  Text(
                                    'Note: $note',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit timetable',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xff087f80),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      editingServiceId = d.id;
                                      selectedRouteId = data['routeId'];
                                      busName.text = data['busName'] ?? '';
                                      offTimingsNote.text =
                                          data['offTimingsNote'] ?? '';
                                      final depMin = (data['departureMinutes']
                                                  as num?)
                                              ?.toInt() ??
                                          0;
                                      departure = TimeOfDay(
                                        hour: (depMin ~/ 60) % 24,
                                        minute: depMin % 60,
                                      );
                                      selectedOffDays.clear();
                                      selectedOffDays.addAll(
                                        (data['offDays'] as List<dynamic>? ??
                                                [])
                                            .map((e) => e.toString()),
                                      );

                                      if (data['stopTimings'] is Map) {
                                        customizeStopTimings = true;
                                        stopTimeValues.clear();
                                        final m = data['stopTimings']
                                            as Map<String, dynamic>;
                                        for (final stop in stopsList) {
                                          if (m.containsKey(stop)) {
                                            final minVal =
                                                (m[stop] as num).toInt();
                                            stopTimeValues[stop] = TimeOfDay(
                                              hour: (minVal ~/ 60) % 24,
                                              minute: minVal % 60,
                                            );
                                          }
                                        }
                                      } else {
                                        customizeStopTimings = false;
                                        initStopTimings(stopsList);
                                      }
                                    });
                                    notice(
                                        'Editing timetable for ${data['busName']}');
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete timetable',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => perform(() async {
                                    await d.reference.delete();
                                    if (editingServiceId == d.id) {
                                      cancelServiceEdit();
                                    }
                                    notice('Timetable deleted');
                                  }),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  // --- APP SCAFFOLD ---

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.directions_bus, color: Color(0xff087f80)),
              SizedBox(width: 8),
              Text(
                'FindMyBus',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: tab == 0
                    ? const Color(0xff087f80).withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              onPressed: () => setState(() => tab = 0),
              child: const Text('Passengers'),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: tab == 1
                    ? const Color(0xff087f80).withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              onPressed: () => setState(() => tab = 1),
              child: const Text('Bus Owners'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xff0c2a47), Color(0xff087f80)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tab == 0
                                ? 'Find Your Bus & Exact Stop Timings'
                                : 'Manage Bus Business & Timetables',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tab == 0
                                ? 'Search routes, check intermediate stop times, return trips, and active service days.'
                                : 'Create and edit routes, update published timetables, customize per-stop departure times, and manage service days.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (tab == 0) passenger() else owner(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void openTrainRouteSheet(
    Map<String, dynamic> data,
    String fromQ,
    String toQ,
    String day,
  ) {
    final isWide = MediaQuery.of(context).size.width > 650;
    if (isWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
            child: TrainRouteView(
              data: data,
              queryFrom: fromQ,
              queryTo: toQ,
              effectiveDay: day,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: TrainRouteView(
              data: data,
              queryFrom: fromQ,
              queryTo: toQ,
              effectiveDay: day,
              scrollController: scroll,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        ),
      );
    }
  }
}

class TrainRouteView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String queryFrom;
  final String queryTo;
  final String effectiveDay;
  final ScrollController? scrollController;
  final VoidCallback? onClose;

  const TrainRouteView({
    super.key,
    required this.data,
    required this.queryFrom,
    required this.queryTo,
    required this.effectiveDay,
    this.scrollController,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final busName = data['busName']?.toString() ?? 'Bus';
    final businessName = data['businessName']?.toString() ?? 'Bus Operator';
    final routeName = data['routeName']?.toString() ?? 'Route';
    final stopsList = (data['stops'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final offDays = (data['offDays'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final offTimings = data['offTimingsNote']?.toString();
    final depM = (data['departureMinutes'] as num?)?.toInt() ?? 0;
    final stopTimings = data['stopTimings'] as Map<String, dynamic>?;

    final isOffToday = offDays.contains(effectiveDay);
    final isToday = (effectiveDay == todayName());
    final curMinutes = minutesNow();

    // Compute times for each stop
    final List<int> times = [];
    int prevTime = depM;
    for (int i = 0; i < stopsList.length; i++) {
      final stop = stopsList[i];
      if (stopTimings != null && stopTimings.containsKey(stop)) {
        prevTime = (stopTimings[stop] as num).toInt();
      } else if (i > 0) {
        prevTime += 15;
      }
      times.add(prevTime);
    }

    final int originTime = times.isNotEmpty ? times.first : depM;
    final int finalTime = times.isNotEmpty ? times.last : (depM + 30);
    final int totalDuration = (finalTime - originTime);

    // Identify user's selected segment
    final int boardIdx = stopsList.indexWhere(
      (s) => s.trim().toLowerCase() == queryFrom.trim().toLowerCase(),
    );
    final int destIdx = stopsList.indexWhere(
      (s) => s.trim().toLowerCase() == queryTo.trim().toLowerCase(),
    );
    final bool hasSegment = boardIdx >= 0 && destIdx > boardIdx;

    // Determine current live bus location index (if running today)
    int liveBusStopIndex = -1;
    bool tripCompleted = false;
    bool tripNotStarted = false;

    if (isToday && !isOffToday && times.isNotEmpty) {
      if (curMinutes < times.first) {
        tripNotStarted = true;
      } else if (curMinutes > times.last) {
        tripCompleted = true;
      } else {
        for (int i = times.length - 1; i >= 0; i--) {
          if (curMinutes >= times[i]) {
            liveBusStopIndex = i;
            break;
          }
        }
      }
    }

    String statusText;
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    if (isOffToday) {
      statusText = 'No service on $effectiveDay (Off: ${offDays.join(', ')})';
      statusBg = Colors.deepOrange.shade50;
      statusFg = Colors.deepOrange.shade900;
      statusIcon = Icons.warning_amber_rounded;
    } else if (!isToday) {
      statusText =
          'Scheduled for $effectiveDay • Departs at ${timeLabel(originTime)}';
      statusBg = const Color(0xffe0f2f1);
      statusFg = const Color(0xff087f80);
      statusIcon = Icons.calendar_today;
    } else if (tripNotStarted) {
      final waitM = times.first - curMinutes;
      statusText =
          'Yet to depart • Starts in $waitM mins (${timeLabel(times.first)})';
      statusBg = Colors.teal.shade50;
      statusFg = Colors.teal.shade900;
      statusIcon = Icons.timer_outlined;
    } else if (tripCompleted) {
      statusText = 'Completed today\'s run (${timeLabel(times.last)})';
      statusBg = Colors.grey.shade100;
      statusFg = Colors.grey.shade800;
      statusIcon = Icons.task_alt;
    } else {
      final nextIdx = (liveBusStopIndex + 1 < stopsList.length)
          ? liveBusStopIndex + 1
          : liveBusStopIndex;
      final nextStop = stopsList[nextIdx];
      final nextTime = times[nextIdx];
      final diff = nextTime - curMinutes;
      statusText = diff > 0
          ? 'Live: Arriving at $nextStop in $diff mins (${timeLabel(nextTime)})'
          : 'Live: At $nextStop station now';
      statusBg = Colors.green.shade50;
      statusFg = Colors.green.shade900;
      statusIcon = Icons.directions_bus;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Train app style top bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff0e2844), Color(0xff087f80)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.directions_bus),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          busName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$businessName • $routeName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Route Overview with train style arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeLabel(originTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stopsList.isNotEmpty ? stopsList.first : 'Origin',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Text(
                          '${totalDuration ~/ 60 > 0 ? "${totalDuration ~/ 60}h " : ""}${totalDuration % 60}m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 2,
                              color: Colors.white54,
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        Text(
                          '${stopsList.length} Stops',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeLabel(finalTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stopsList.isNotEmpty ? stopsList.last : 'Final',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live status chip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: statusBg,
          child: Row(
            children: [
              Icon(statusIcon, size: 16, color: statusFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Passenger's Trip Highlight banner (if matched)
        if (hasSegment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              border: Border(
                bottom: BorderSide(color: Colors.green.shade200),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Trip: ${stopsList[boardIdx]} (${timeLabel(times[boardIdx])}) → ${stopsList[destIdx]} (${timeLabel(times[destIdx])}) • ${times[destIdx] - times[boardIdx]} mins (${destIdx - boardIdx} stops)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Non-service note (if any)
        if (offTimings != null && offTimings.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.brown),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Schedule Note: $offTimings',
                    style: const TextStyle(fontSize: 11, color: Colors.brown),
                  ),
                ),
              ],
            ),
          ),

        // Vertical Train Route Station Ladder
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: stopsList.length,
            itemBuilder: (context, i) {
              final stopName = stopsList[i];
              final stopTime = times[i];
              final isFirst = i == 0;
              final isLast = i == stopsList.length - 1;
              final isBoarding = i == boardIdx;
              final isDest = i == destIdx;
              final inSegment = hasSegment && (i >= boardIdx && i <= destIdx);
              final isPassed = isToday &&
                  !isOffToday &&
                  !tripNotStarted &&
                  (tripCompleted || i <= liveBusStopIndex);
              final isLiveHere = isToday &&
                  !isOffToday &&
                  !tripNotStarted &&
                  !tripCompleted &&
                  (i == liveBusStopIndex);

              // Ladder line colors
              final Color topTrackColor =
                  (hasSegment && i > boardIdx && i <= destIdx)
                      ? const Color(0xff087f80)
                      : (isPassed
                          ? Colors.teal.shade200
                          : Colors.grey.shade300);
              final Color bottomTrackColor =
                  (hasSegment && i >= boardIdx && i < destIdx)
                      ? const Color(0xff087f80)
                      : (isPassed && i < liveBusStopIndex
                          ? Colors.teal.shade200
                          : Colors.grey.shade300);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Column 1: Station Scheduled Time
                    SizedBox(
                      width: 72,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            timeLabel(stopTime),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: (isBoarding || isDest || isLiveHere)
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isBoarding
                                  ? Colors.green.shade800
                                  : (isDest
                                      ? Colors.red.shade800
                                      : (isPassed
                                          ? Colors.grey.shade500
                                          : Colors.black87)),
                            ),
                          ),
                          if (i > 0)
                            Text(
                              '+${stopTime - times[i - 1]}m',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          if (isPassed && !isLiveHere)
                            Text(
                              'Passed',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Column 2: Railway Track / Station Ladder Node
                    SizedBox(
                      width: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Top connector track line
                          if (!isFirst)
                            Positioned(
                              top: 0,
                              bottom: 24,
                              child: Container(
                                width: (hasSegment &&
                                        i > boardIdx &&
                                        i <= destIdx)
                                    ? 4
                                    : 2,
                                color: topTrackColor,
                              ),
                            ),
                          // Bottom connector track line
                          if (!isLast)
                            Positioned(
                              top: 24,
                              bottom: 0,
                              child: Container(
                                width: (hasSegment &&
                                        i >= boardIdx &&
                                        i < destIdx)
                                    ? 4
                                    : 2,
                                color: bottomTrackColor,
                              ),
                            ),

                          // Station Node Marker
                          Positioned(
                            top: 10,
                            child: isLiveHere
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.directions_bus,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                : isBoarding
                                    ? Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.my_location,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      )
                                    : isDest
                                        ? Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: inSegment
                                                  ? const Color(0xff087f80)
                                                  : (isPassed
                                                      ? Colors.teal.shade300
                                                      : Colors.white),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: inSegment
                                                    ? const Color(0xff087f80)
                                                    : Colors.grey.shade400,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Column 3: Station Name & Status Information
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    stopName,
                                    style: TextStyle(
                                      fontSize:
                                          (isBoarding || isDest) ? 15 : 14,
                                      fontWeight: (isBoarding ||
                                              isDest ||
                                              isFirst ||
                                              isLast)
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isBoarding
                                          ? Colors.green.shade900
                                          : (isDest
                                              ? Colors.red.shade900
                                              : (isPassed && !isLiveHere
                                                  ? Colors.grey.shade600
                                                  : Colors.black87)),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Stop #${i + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),

                            // Tags / Badges for Station
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (isLiveHere)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '🚌 BUS IS HERE NOW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                if (isBoarding)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.green.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      '🟢 YOUR BOARDING STOP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                if (isDest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      '🔴 YOUR DESTINATION STOP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                if (isFirst && !isBoarding)
                                  Text(
                                    'Origin Terminal Station',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                if (isLast && !isDest)
                                  Text(
                                    'Final Destination Terminal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom close bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Train-style timetable track',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              FilledButton.tonal(
                onPressed: onClose ?? () => Navigator.pop(context),
                child: const Text('Close Route'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

