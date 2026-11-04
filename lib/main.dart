import 'package:flutter/material.dart';

void main() => runApp(const BusConnect());
class Bus {
  final String name, from, to;
  final int departure, duration;
  const Bus(this.name, this.from, this.to, this.departure, this.duration);
}
String clock(int minutes) {
  final h = (minutes ~/ 60) % 24, m = minutes % 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}
class BusConnect extends StatelessWidget {
  const BusConnect({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kerala Bus Connect',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff087f80), scaffoldBackgroundColor: const Color(0xfff4f7fa)),
    home: const BusHome(),
  );
}
class BusHome extends StatefulWidget {
  const BusHome({super.key});
  @override
  State<BusHome> createState() => _BusHomeState();
}
class _BusHomeState extends State<BusHome> {
  final towns = ['Thrissur', 'Guruvayur', 'Kunnamkulam', 'Ernakulam', 'Aluva', 'Chalakudy', 'Palakkad'];
  final buses = <Bus>[
    const Bus('Malabar Express', 'Thrissur', 'Guruvayur', 420, 65),
    const Bus('City Rider', 'Thrissur', 'Guruvayur', 445, 65),
    const Bus('Green Line', 'Thrissur', 'Guruvayur', 490, 65),
    const Bus('Coastal Star', 'Thrissur', 'Guruvayur', 535, 65),
    const Bus('Royal Travels', 'Thrissur', 'Guruvayur', 600, 65),
    const Bus('Metro Link', 'Ernakulam', 'Aluva', 450, 50),
    const Bus('Blue Bird', 'Ernakulam', 'Aluva', 495, 50),
    const Bus('Highway Rider', 'Thrissur', 'Chalakudy', 480, 45),
  ];
  String from = 'Thrissur', to = 'Guruvayur';
  int tab = 0, separation = 15;
  TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
  final name = TextEditingController();
  List<Bus> get route => buses.where((b) => b.from == from && b.to == to).toList()
    ..sort((a, b) => a.departure.compareTo(b.departure));
  List<(int, int)> get suggestions {
    final list = route, gaps = <(int, int)>[];
    for (var i = 0; i < list.length - 1; i++) {
      final gap = list[i + 1].departure - list[i].departure;
      if (gap >= separation * 2) gaps.add((list[i].departure + gap ~/ 2, gap));
    }
    gaps.sort((a, b) => b.$2.compareTo(a.$2));
    return gaps.take(3).toList();
  }
  @override
  void dispose() { name.dispose(); super.dispose(); }
  Widget panel(String heading, Widget child) => Card(
    elevation: 0, color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(heading, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 14), child],
    )),
  );
  Widget townPicker(String label, String value, ValueChanged<String?> change) =>
    DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: towns.map((town) => DropdownMenuItem(value: town, child: Text(town))).toList(),
      onChanged: change,
    );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 750, services = route;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.directions_bus, color: Color(0xff087f80)), SizedBox(width: 10), Flexible(child: Text('Kerala Bus Connect'))]),
        actions: wide ? [
          TextButton(onPressed: () => setState(() => tab = 0), child: const Text('Passenger Search')),
          TextButton(onPressed: () => setState(() => tab = 1), child: const Text('Owner Dashboard')),
          const SizedBox(width: 16),
        ] : null,
      ),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Find buses'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Bus owner'),
        ],
      ),
      body: SingleChildScrollView(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff11263d), Color(0xff087f80)]), borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tab == 0 ? 'Find your next bus' : 'Optimize your departure time',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(tab == 0 ? 'Search routes and compare scheduled departures.' : 'Discover timetable gaps and manage bus departures.',
                  style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                const Text('KERALA • SAMPLE DATA', style: TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 16),
            panel('Select route', Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: wide ? 290 : double.infinity, child: townPicker('From', from, (v) => setState(() => from = v!))),
              IconButton.filledTonal(onPressed: () => setState(() { final old = from; from = to; to = old; }), icon: const Icon(Icons.swap_horiz)),
              SizedBox(width: wide ? 290 : double.infinity, child: townPicker('To', to, (v) => setState(() => to = v!))),
            ])),
            const SizedBox(height: 12),
            if (tab == 0)
              panel('${services.length} bus services', services.isEmpty
                ? const Text('No sample services for this route. Try Thrissur → Guruvayur.')
                : Column(children: services.map((bus) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.directions_bus)),
                    title: Text(bus.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Departure ${clock(bus.departure)} • Arrival ${clock(bus.departure + bus.duration)}'),
                    trailing: Text('${bus.duration} min'),
                  )).toList()))
            else ...[
              panel('Best departure slots', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Minimum separation: $separation minutes'),
                Slider(value: separation.toDouble(), min: 5, max: 30, divisions: 5,
                  label: '$separation min', onChanged: (v) => setState(() => separation = v.round())),
                if (suggestions.isEmpty) const Text('Add two services with a sufficient gap.'),
                ...suggestions.map((g) => Card(
                  color: const Color(0xffe4f5ee),
                  child: ListTile(leading: const Icon(Icons.auto_awesome, color: Color(0xff087f80)),
                    title: Text(clock(g.$1), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Midpoint of a ${g.$2}-minute gap')),
                )),
                const SizedBox(height: 8),
                const Text('Gap-only suggestions; demand, permits, traffic and profitability are not verified.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              ])),
              panel('Add bus departure', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Bus name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: selectedTime);
                  if (picked != null) setState(() => selectedTime = picked);
                }, icon: const Icon(Icons.schedule), label: Text('Departure: ${selectedTime.format(context)}')),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: () {
                  if (name.text.trim().isEmpty || from == to) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a bus name and choose different towns')));
                    return;
                  }
                  setState(() {
                    buses.add(Bus(name.text.trim(), from, to, selectedTime.hour * 60 + selectedTime.minute, 60));
                    name.clear();
                  });
                }, icon: const Icon(Icons.add), label: const Text('Add to timetable')),
              ])),
              panel('Existing departures', services.isEmpty
                ? const Text('No departures yet.')
                : Column(children: services.map((bus) => ListTile(
                  title: Text(bus.name), subtitle: Text(clock(bus.departure)),
                  trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => buses.remove(bus))),
                )).toList())),
            ],
            const SizedBox(height: 18),
            const Text('Prototype • Illustrative schedules only. Changes are session-only.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        )),
      ))),
    );
  }
}
