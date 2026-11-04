import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB7h2kuVM8CvhNlkptsPtyKXXHUO4T1RQk',
  appId: '1:442982526142:web:6daaf45238e0cf8de442ef',
  messagingSenderId: '442982526142',
  projectId: 'findmybus-535ae',
  authDomain: 'findmybus-535ae.firebaseapp.com',
  storageBucket: 'findmybus-535ae.firebasestorage.app',
);

// --- DESIGN SYSTEM CONSTANTS ---
class AppColors {
  static const primary = Color(0xff005c55);
  static const primaryContainer = Color(0xff0f766e);
  static const onPrimary = Color(0xffffffff);
  static const onPrimaryContainer = Color(0xffa3faef);
  static const secondary = Color(0xff006a61);
  static const secondaryContainer = Color(0xffccfbf1);
  static const onSecondaryContainer = Color(0xff006f66);
  static const tertiary = Color(0xff7d4200);
  static const tertiaryContainer = Color(0xffa15600);
  static const tertiaryFixed = Color(0xffffdcc3);
  static const onTertiaryFixed = Color(0xff2f1500);
  static const background = Color(0xfff8fafc);
  static const surface = Color(0xfffaf8ff);
  static const surfaceLow = Color(0xfff1f5f9);
  static const surfaceHigh = Color(0xffeaedff);
  static const surfaceContainerHighest = Color(0xffdae2fd);
  static const card = Color(0xffffffff);
  static const onSurface = Color(0xff0f172a);
  static const onSurfaceVariant = Color(0xff475569);
  static const outline = Color(0xff64748b);
  static const outlineVariant = Color(0xffcbd5e1);
  static const border = Color(0xffe2e8f0);
}

const weekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const popularKeralaStops = [
  'Aluva',
  'Kaloor',
  'Infopark Kakkanad',
  'Edappally Toll',
  'Fort Kochi',
  'Kozhikode',
  'Kannur',
  'Angamaly',
  'Thrissur',
  'Kottayam',
  'Palakkad',
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
        title: 'FindMyBus - Kerala Bus Connect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Plus Jakarta Sans',
          fontFamilyFallback: const ['Inter', 'sans-serif'],
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
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
  final searchFrom = TextEditingController(text: 'Aluva');
  final searchTo = TextEditingController(text: 'Kaloor');
  String filterDay = 'All Days';
  bool onlyRunningToday = false;

  int navIndex = 0; // 0: Timetables, 1: Live Track, 2: Routes, 3: Owners Portal
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
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            register ? 'Create Owner Account' : 'Bus Owner Login',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Operator Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password (6+ characters)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => refresh(() => register = !register),
                  child: Text(
                    register
                        ? 'Already registered? Sign in'
                        : 'New business owner? Register here',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w600),
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
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

  // --- REUSABLE MODERN COMPONENTS ---

  Widget cardContainer({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget modernField(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? prefixIcon,
    Color? iconColor,
    VoidCallback? onClear,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              Icon(prefixIcon,
                  size: 20, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  TextField(
                    controller: controller,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: AppColors.outlineVariant,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.only(top: 2, bottom: 2),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null && controller.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.cancel,
                    size: 18, color: AppColors.outlineVariant),
                onPressed: onClear,
              ),
          ],
        ),
      );

  // --- HEADER APP BAR ---

  PreferredSizeWidget buildHeader() {
    final isOwnerMode = navIndex == 3;
    return PreferredSize(
      preferredSize: const Size.fromHeight(116),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FindMyBus',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          isOwnerMode
                              ? 'Bus Owner Operator Portal'
                              : 'Search Timetables & Live Routes',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification icon
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: AppColors.onSurfaceVariant, size: 22),
                    tooltip: 'Transit Alerts',
                    onPressed: () => notice(
                      'All private bus services across Kerala running on normal schedule.',
                    ),
                  ),
                  // Profile / Auth icon
                  StreamBuilder<User?>(
                    stream: auth.authStateChanges(),
                    builder: (context, snap) {
                      final user = snap.data;
                      return InkWell(
                        onTap: () {
                          if (user == null) {
                            loginDialog();
                          } else {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Operator Account'),
                                content: Text('Signed in as: ${user.email}'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      auth.signOut();
                                      Navigator.pop(ctx);
                                      notice('Signed out');
                                    },
                                    child: const Text('Sign out'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: user != null
                                ? AppColors.primary
                                : AppColors.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            user != null ? Icons.person : Icons.login,
                            size: 18,
                            color: user != null
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Segmented Tab Selector pill (from redesign)
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => navIndex = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: navIndex != 3
                                ? AppColors.card
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: navIndex != 3
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Passengers',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: navIndex != 3
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: navIndex != 3
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => navIndex = 3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: navIndex == 3
                                ? AppColors.card
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: navIndex == 3
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Bus Owners',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: navIndex == 3
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: navIndex == 3
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PASSENGER UI ---

  Widget passengerView() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Card Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryContainer,
                  AppColors.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    Icons.directions_bus,
                    size: 90,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xff86f2e4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Kerala State & Private Transit Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Find Your Bus & Exact Stop Timings',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Search routes, check intermediate stop times, return trips, and active service days across Kerala.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Search Card Component
          cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.search, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Search Buses & Timetables',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: const Text(
                        'KSRTC + Private',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Stacked Boarding & Destination Inputs with Floating Swap
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Column(
                      children: [
                        modernField(
                          searchFrom,
                          'Boarding Location / Stop',
                          hint: 'E.g., Aluva, Kozhikode, Kannur',
                          prefixIcon: Icons.my_location,
                          iconColor: AppColors.primary,
                          onClear: () => setState(() => searchFrom.clear()),
                        ),
                        const SizedBox(height: 8),
                        modernField(
                          searchTo,
                          'Destination Stop',
                          hint: 'E.g., Kaloor, Vadakara, Fort Kochi',
                          prefixIcon: Icons.location_on,
                          iconColor: AppColors.tertiaryContainer,
                          onClear: () => setState(() => searchTo.clear()),
                        ),
                      ],
                    ),
                    // Floating Swap Trigger
                    Positioned(
                      right: 14,
                      child: Material(
                        elevation: 3,
                        shape: const CircleBorder(),
                        color: AppColors.card,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() {
                              final temp = searchFrom.text;
                              searchFrom.text = searchTo.text;
                              searchTo.text = temp;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.swap_vert,
                                size: 22, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Popular Destination Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Popular:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ...popularKeralaStops.map(
                        (stop) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(stop),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                            backgroundColor: AppColors.surfaceLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            onPressed: () {
                              setState(() => searchTo.text = stop);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Day selector & Status row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter by Day:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: filterDay,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.expand_more, size: 18),
                        items: ['All Days', ...weekDays].map((day) {
                          final isToday = day == todayName();
                          return DropdownMenuItem(
                            value: day,
                            child: Text(
                              isToday ? '$day (Today)' : day,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday
                                    ? AppColors.primary
                                    : AppColors.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => filterDay = v);
                        },
                      ),
                      const Spacer(),
                      FilterChip(
                        selected: onlyRunningToday,
                        label: Text(
                          'Running on ${filterDay == 'All Days' ? todayName() : filterDay}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        selectedColor: AppColors.secondaryContainer,
                        checkmarkColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: onlyRunningToday
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() => onlyRunningToday = selected);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Primary CTA Button
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text(
                      'Find Buses',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Departures List with Live Sync Badge
          servicesStream(),

          const SizedBox(height: 16),

          // 4. Quick Utility Actions Grid
          Row(
            children: [
              Expanded(
                child: utilityCard(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Save Route',
                  onTap: () => notice(
                      'Route "${searchFrom.text} → ${searchTo.text}" saved to your favourites!'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: utilityCard(
                  icon: Icons.sync_alt,
                  title: 'Return Trips',
                  onTap: () {
                    setState(() {
                      final t = searchFrom.text;
                      searchFrom.text = searchTo.text;
                      searchTo.text = t;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: utilityCard(
                  icon: Icons.share_outlined,
                  title: 'Share Schedule',
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text:
                          'Check bus timings from ${searchFrom.text} to ${searchTo.text} on FindMyBus!',
                    ));
                    notice('Bus schedule copied to clipboard!');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 5. Kerala Bus Notice Card (from redesign)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 24, color: AppColors.secondary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Private Bus Concession & Peak Hour Notice',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'During peak school and office hours (8:30 AM - 10:00 AM), express services run at high frequencies along Kerala highway corridors. Have exact change or UPI ready for the conductor.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );

  Widget utilityCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: cardContainer(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget servicesStream() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('services')
            .where('published', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return cardContainer(
              child: Text(
                'Unable to load timetables: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Departures header with animated ping
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        isLookingAtToday
                            ? 'Upcoming Departures Today (${upcoming.length})'
                            : 'Departures for $effectiveDay (${matches.length})',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors,
                            size: 13, color: AppColors.onSecondaryContainer),
                        SizedBox(width: 4),
                        Text(
                          'Live Sync Active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (upcoming.isEmpty)
                cardContainer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        isLookingAtToday
                            ? 'No more scheduled departures today for this route.'
                            : 'No published departures match this search on $effectiveDay.',
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: upcoming
                      .map((d) => modernBusCard(d, a, b, effectiveDay))
                      .toList(),
                ),

              const SizedBox(height: 16),

              // All services header
              Text(
                'All Published Route Services (${matches.length})',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              if (matches.isEmpty)
                cardContainer(
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No published buses match this stop-to-stop search.',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: matches
                      .map((d) => modernBusCard(d, a, b, effectiveDay))
                      .toList(),
                ),
            ],
          );
        },
      );

  Widget modernBusCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String a,
    String b,
    String effectiveDay,
  ) {
    final d = doc.data();
    final stopsList =
        (d['stops'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final offDays =
        (d['offDays'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final offTimings = d['offTimingsNote']?.toString();
    final isOffOnSelectedDay = offDays.contains(effectiveDay);

    final boardTime = getBoardingTime(d, a);
    final destTime = getDestinationTime(d, b, fallback: boardTime + 30);
    final diffMinutes = boardTime - minutesNow();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isOffOnSelectedDay ? const Color(0xfffff9f5) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffOnSelectedDay ? Colors.orange.shade200 : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openTrainRouteSheet(d, a, b, effectiveDay),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Bus avatar + name + departure time
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isOffOnSelectedDay
                            ? Colors.orange.shade100
                            : AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.directions_bus,
                        color: isOffOnSelectedDay
                            ? Colors.deepOrange
                            : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                d['busName']?.toString() ?? 'Bus',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Limited Stop',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${d['businessName'] ?? 'Operator'} • Bay Service',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
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
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        if (effectiveDay == todayName() && !isOffOnSelectedDay)
                          Text(
                            diffMinutes > 0
                                ? 'in $diffMinutes mins'
                                : 'Departed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: diffMinutes > 0
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stops progression arrow row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stopsList.join(' → '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '₹22',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Live status & detail pill bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOffOnSelectedDay
                              ? Colors.red.shade100
                              : AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOffOnSelectedDay
                                  ? Icons.cancel
                                  : Icons.check_circle,
                              size: 12,
                              color: isOffOnSelectedDay
                                  ? Colors.red.shade900
                                  : AppColors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOffOnSelectedDay ? 'Off Today' : 'On Time',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOffOnSelectedDay
                                    ? Colors.red.shade900
                                    : AppColors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (destTime > boardTime)
                        Text(
                          'Arrival est: ${timeLabel(destTime)} (${destTime - boardTime}m)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      const Spacer(),
                      const Text(
                        'Stops Path',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ),

                if (offTimings != null && offTimings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ℹ️ $offTimings',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  // --- TRAIN ROUTE MODAL / SHEET ---

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  // --- OWNER UI ---

  Widget ownerView() => StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return cardContainer(
              child: Column(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Bus Owner & Fleet Management',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in or register to manage bus fleets, multiple routes, return trips, stop timings, and conflict-free timetables.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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
              // Owner Account Card
              cardContainer(
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.surfaceHigh,
                      child: Icon(Icons.business, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in as Operator:',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                          Text(
                            user.email ?? 'Operator',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => auth.signOut(),
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Create Bus Operator Business Card
              cardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Bus Business / Operator',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    modernField(
                      business,
                      'Business / Operator Name',
                      hint: 'e.g. Malabar Travels, Royal Bus Service',
                      prefixIcon: Icons.add_business,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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
                      icon: const Icon(Icons.add),
                      label: const Text('Create Business'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Businesses Stream
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('businesses')
                    .where('ownerId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return cardContainer(
                      child: Text('Loading failed: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final businesses = snapshot.data!.docs;
                  if (businesses.isEmpty) {
                    return cardContainer(
                      child: const Center(
                        child: Text(
                          'No businesses created yet. Add one above to create routes and timetables.',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
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
                      // Active Operator Selector
                      cardContainer(
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selected,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Active Operator',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: businesses.map((d) {
                                  return DropdownMenuItem(
                                    value: d.id,
                                    child: Text(
                                      d.data()['name']?.toString() ??
                                          'Business',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }).toList(),
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
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppColors.primary),
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
                      const SizedBox(height: 16),
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
            return cardContainer(
              child: Text('Routes error: ${routesSnap.error}'),
            );
          }
          if (!routesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = routesSnap.data!.docs;
          final isEditingThisRoute = editingRouteId != null;

          return Column(
            children: [
              // Add / Edit Route Form Card
              cardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditingThisRoute
                              ? 'Edit Route'
                              : 'Add Route & Return Route',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (isEditingThisRoute)
                          TextButton(
                            onPressed: cancelRouteEdit,
                            child: const Text('Cancel Edit'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    modernField(
                      routeName,
                      'Route Name (optional)',
                      hint: 'e.g. Kozhikode - Kannur Express',
                      prefixIcon: Icons.route,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: modernField(
                            from,
                            'Starting Stop',
                            hint: 'e.g. Kozhikode',
                            prefixIcon: Icons.my_location,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: modernField(
                            to,
                            'Last Stop',
                            hint: 'e.g. Kannur',
                            prefixIcon: Icons.location_on,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    modernField(
                      stops,
                      'Intermediate Stops (comma-separated)',
                      hint: 'e.g. Koyilandy, Vadakara, Thalassery',
                      prefixIcon: Icons.alt_route,
                    ),
                    if (!isEditingThisRoute) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Automatically generate return route (reversed stops)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Creates both outbound and return routes simultaneously.',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: createReturnRouteToo,
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => createReturnRouteToo = v),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: busy
                          ? null
                          : () => perform(() async {
                                final start = from.text.trim();
                                final end = to.text.trim();
                                if (start.isEmpty ||
                                    end.isEmpty ||
                                    start.toLowerCase() == end.toLowerCase()) {
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
                                final mainName = routeName.text.trim().isEmpty
                                    ? '$start → $end'
                                    : routeName.text.trim();

                                if (isEditingThisRoute) {
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

                                  // Sync across timetables using this route
                                  final relatedServices = await db
                                      .collection('services')
                                      .where('routeId',
                                          isEqualTo: editingRouteId)
                                      .get();
                                  for (final sDoc in relatedServices.docs) {
                                    await sDoc.reference.update({
                                      'routeName': mainName,
                                      'stops': forwardStops,
                                      'ownerId': user.uid,
                                    });
                                  }

                                  cancelRouteEdit();
                                  notice('Route updated successfully!');
                                } else {
                                  final ref =
                                      await db.collection('routes').add({
                                    'ownerId': user.uid,
                                    'businessId': businessId,
                                    'businessName': operatorDoc.data()['name'],
                                    'name': mainName,
                                    'startStop': start,
                                    'endStop': end,
                                    'stops': forwardStops,
                                    'isReturn': false,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  setState(() => selectedRouteId = ref.id);

                                  if (createReturnRouteToo) {
                                    final returnStops =
                                        forwardStops.reversed.toList();
                                    final returnName = '$end → $start (Return)';
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
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                  }

                                  routeName.clear();
                                  from.clear();
                                  to.clear();
                                  stops.clear();
                                  notice(createReturnRouteToo
                                      ? 'Main and return routes created!'
                                      : 'Route created!');
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Existing Routes List
              if (routes.isNotEmpty) ...[
                cardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Operator Routes (${routes.length})',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...routes.map((doc) {
                        final r = doc.data();
                        final stopsList = (r['stops'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();
                        final isSelected = doc.id == selectedRouteId;
                        final isReturn = r['isReturn'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            color: isSelected
                                ? AppColors.secondaryContainer
                                    .withValues(alpha: 0.3)
                                : AppColors.card,
                          ),
                          child: ListTile(
                            leading: Icon(
                              isReturn ? Icons.keyboard_return : Icons.route,
                              color: isReturn
                                  ? Colors.deepOrange
                                  : AppColors.primary,
                            ),
                            title: Text(
                              r['name']?.toString() ?? 'Route',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${stopsList.join(' → ')} (${stopsList.length} stops)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit route',
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: AppColors.primary),
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
                                              .sublist(1, stopsList.length - 1)
                                              .join(', ')
                                          : '';
                                    });
                                    notice('Editing route: ${r['name']}');
                                  },
                                ),
                                if (!isReturn &&
                                    !routes.any((other) =>
                                        other.data()['returnOfRouteId'] ==
                                        doc.id))
                                  IconButton(
                                    tooltip: 'Generate return route',
                                    icon: const Icon(Icons.swap_calls,
                                        size: 18, color: Colors.deepOrange),
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
                                  tooltip: 'Delete route',
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  onPressed: () => perform(() async {
                                    await doc.reference.delete();
                                    if (selectedRouteId == doc.id) {
                                      setState(() => selectedRouteId = null);
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
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Timetable Publisher Section
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
      return cardContainer(
        child: const Text('Add a route above to publish timetables.'),
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
            // Publish / Edit Timetable Card
            cardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditingService
                            ? 'Edit Bus Timetable'
                            : 'Publish Bus Timetable',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (isEditingService)
                        TextButton(
                          onPressed: cancelServiceEdit,
                          child: const Text('Cancel Edit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRoute,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Route',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                  const SizedBox(height: 10),
                  modernField(
                    busName,
                    'Bus Name / Registration',
                    hint: 'e.g. Malabar King (KL-11-AB-1234)',
                    prefixIcon: Icons.directions_bus,
                  ),
                  const SizedBox(height: 10),

                  // Departure time picker
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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
                    icon: const Icon(Icons.schedule, color: AppColors.primary),
                    label: Text(
                      'Departure from ${routeStops.first}: ${departure.format(context)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ExpansionTile for individual stop timings
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Optional: Set Each Stop Timing',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Checkbox(
                            value: customizeStopTimings,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(
                                () => customizeStopTimings = v ?? false),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        customizeStopTimings
                            ? 'Custom timings configured for all ${routeStops.length} stops.'
                            : 'Tap to configure custom times for intermediate stops.',
                        style: const TextStyle(fontSize: 11),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: routeStops.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final stop = entry.value;
                              final currentT = stopTimeValues[stop] ??
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
                                      radius: 10,
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        '${idx + 1}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        stop,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.access_time,
                                          size: 14),
                                      label: Text(
                                        currentT.format(context),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: currentT,
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            customizeStopTimings = true;
                                            stopTimeValues[stop] = picked;
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
                  ),
                  const SizedBox(height: 10),

                  // Off Days selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event_busy,
                                size: 16, color: Colors.deepOrange),
                            SizedBox(width: 6),
                            Text(
                              'Non-service Days (Off Days)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: weekDays.map((day) {
                            final isOff = selectedOffDays.contains(day);
                            return FilterChip(
                              label: Text(day,
                                  style: const TextStyle(fontSize: 11)),
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
                  const SizedBox(height: 10),

                  modernField(
                    offTimingsNote,
                    'Schedule Notes / Blackout timings (Optional)',
                    hint: 'e.g. No service 1:00 PM - 2:00 PM',
                    prefixIcon: Icons.notes,
                  ),
                  const SizedBox(height: 14),

                  // Save / Publish Timetable Button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: busy
                        ? null
                        : () => perform(() async {
                              final name = busName.text.trim();
                              if (name.isEmpty) {
                                throw Exception('Enter bus name');
                              }

                              final depMinutes =
                                  departure.hour * 60 + departure.minute;

                              // Conflict check: only same bus vehicle conflicts within 30m
                              for (final existing in businessServices) {
                                if (existing.id == editingServiceId) continue;
                                final edata = existing.data();
                                final existingBus =
                                    edata['busName']?.toString().toLowerCase();
                                final existingDep =
                                    (edata['departureMinutes'] as num?)?.toInt() ??
                                        0;
                                final existingRouteName =
                                    edata['routeName'] ?? 'another route';

                                if (existingBus == name.toLowerCase()) {
                                  final diff = (depMinutes - existingDep).abs();
                                  if (diff < 30) {
                                    throw Exception(
                                      'Vehicle Conflict: Bus "$name" is already scheduled at ${timeLabel(existingDep)} on $existingRouteName. The same bus vehicle cannot operate two overlapping trips. (Different buses are allowed at the same time).',
                                    );
                                  }
                                }
                              }

                              final Map<String, int> finalStopTimings = {};
                              if (customizeStopTimings) {
                                for (final stop in routeStops) {
                                  final t = stopTimeValues[stop] ?? departure;
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

                              final payload = {
                                'ownerId': user.uid,
                                'businessId': businessId,
                                'routeId': selectedRoute,
                                'businessName': operatorDoc.data()['name'],
                                'routeName': routeData['name'],
                                'busName': name,
                                'stops': routeStops,
                                'departureMinutes': depMinutes,
                                'stopTimings': finalStopTimings,
                                'offDays': selectedOffDays.toList(),
                                'offTimingsNote': offTimingsNote.text.trim(),
                                'published': true,
                              };

                              if (isEditingService) {
                                await db
                                    .collection('services')
                                    .doc(editingServiceId)
                                    .update(payload);
                                cancelServiceEdit();
                                notice('Timetable updated successfully!');
                              } else {
                                await db.collection('services').add({
                                  ...payload,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                cancelServiceEdit();
                                notice('Timetable published successfully!');
                              }
                            }),
                    icon: Icon(isEditingService ? Icons.save : Icons.publish),
                    label: Text(
                      isEditingService
                          ? 'Save Timetable Changes'
                          : 'Publish Timetable',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Published Timetables List Card
            cardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Published Bus Timetables (${businessServices.length})',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (businessServices.isEmpty)
                    const Text(
                      'No timetables published yet for this business.',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13),
                    )
                  else
                    ...businessServices.map((d) {
                      final data = d.data();
                      final depM =
                          (data['departureMinutes'] as num?)?.toInt() ?? 0;
                      final stopsList = (data['stops'] as List<dynamic>? ?? [])
                          .map((e) => e.toString())
                          .toList();
                      final offDays = (data['offDays'] as List<dynamic>? ?? [])
                          .map((e) => e.toString())
                          .toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceHigh,
                            child: Icon(Icons.schedule,
                                color: AppColors.primary),
                          ),
                          title: Text(
                            '${data['busName']} • ${timeLabel(depM)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Route: ${data['routeName'] ?? stopsList.join(' → ')}${offDays.isNotEmpty ? " (Off: ${offDays.join(', ')})" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: AppColors.primary),
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
                                      (data['offDays'] as List<dynamic>? ?? [])
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
                                    }
                                  });
                                  notice(
                                      'Editing timetable: ${data['busName']}');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
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
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- MAIN APP SCAFFOLD ---

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: buildHeader(),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: navIndex == 3 ? ownerView() : passengerView(),
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  bottomNavItem(
                    icon: Icons.schedule,
                    label: 'Timetables',
                    isActive: navIndex == 0,
                    onTap: () => setState(() => navIndex = 0),
                  ),
                  bottomNavItem(
                    icon: Icons.fmd_good_outlined,
                    label: 'Live Track',
                    isActive: navIndex == 1,
                    onTap: () {
                      setState(() {
                        navIndex = 0;
                        onlyRunningToday = true;
                      });
                      notice('Showing active live running buses today!');
                    },
                  ),
                  bottomNavItem(
                    icon: Icons.alt_route,
                    label: 'Routes',
                    isActive: navIndex == 2,
                    onTap: () {
                      setState(() => navIndex = 0);
                      notice(
                          'Showing all routes. Select or search any stops.');
                    },
                  ),
                  bottomNavItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Owners Portal',
                    isActive: navIndex == 3,
                    onTap: () => setState(() => navIndex = 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget bottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

// --- TRAIN ROUTE STATION LADDER VIEW ---

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
      statusBg = AppColors.secondaryContainer;
      statusFg = AppColors.onSecondaryContainer;
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
              colors: [
                AppColors.primary,
                AppColors.primaryContainer,
                AppColors.secondary,
              ],
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          busName,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
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
                            fontFamily: 'Plus Jakarta Sans',
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
                            fontFamily: 'Plus Jakarta Sans',
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
                      ? AppColors.primary
                      : (isPassed
                          ? Colors.teal.shade200
                          : Colors.grey.shade300);
              final Color bottomTrackColor =
                  (hasSegment && i >= boardIdx && i < destIdx)
                      ? AppColors.primary
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
                              fontFamily: 'Inter',
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
                                          : AppColors.onSurface)),
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

                          // Node Marker
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
                                                  ? AppColors.primary
                                                  : (isPassed
                                                      ? Colors.teal.shade300
                                                      : Colors.white),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: inSegment
                                                    ? AppColors.primary
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

                    // Column 3: Station Name & Details
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
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize:
                                          (isBoarding || isDest) ? 15 : 14,
                                      fontWeight: (isBoarding ||
                                              isDest ||
                                              isFirst ||
                                              isLast)
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isBoarding
                                          ? Colors.green.shade900
                                          : (isDest
                                              ? Colors.red.shade900
                                              : (isPassed && !isLiveHere
                                                  ? Colors.grey.shade600
                                                  : AppColors.onSurface)),
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

                            // Badges for Station
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

        // Bottom bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLow,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Train-style timetable track',
                style:
                    TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.primary,
                ),
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
