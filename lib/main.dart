import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Monitor',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = FirebaseDatabase.instance.ref();
  Map<String, dynamic> usersMap = {};

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final snapshot = await db.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        usersMap = data;
      });
    }
  }

  Future<void> toggleState(String userKey, bool currentState) async {
    if (!currentState) {
      final snapshot = await db.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        for (var key in data.keys) {
          await db.child(key).update({'State': 0});
        }
      }
    }
    final newState = currentState ? 0 : 1;
    await db.child(userKey).update({'State': newState});
    fetchUsers();
  }


  Future<void> addUser(String name) async {
    if (name.isEmpty) return;
    await db.child(name).set({'State': 0});
    fetchUsers();
  }

  void showAddUserDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Добавить пользователя'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Имя пользователя'),
        ),
        actions: [
          TextButton(
            child: Text('Отмена'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Добавить'),
            onPressed: () {
              addUser(controller.text.trim());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Пользователи")),
      body: usersMap.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView(
        children: usersMap.entries.map((entry) {
          final user = entry.key;
          final state = (entry.value['State'] ?? 0) == 1;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(user),
              trailing: Switch(
                value: state,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                onChanged: (val) => toggleState(user, state),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserDataScreen(userId: user),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddUserDialog,
        child: Icon(Icons.add),
        tooltip: 'Добавить пользователя',
      ),
    );
  }
}

class UserDataScreen extends StatefulWidget {
  final String userId;
  UserDataScreen({required this.userId});

  @override
  _UserDataScreenState createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  final db = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? latestData;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    fetchData();
    _timer = Timer.periodic(Duration(seconds: 1), (_) => fetchData());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    final snapshot = await db.child('${widget.userId}/time_data').get();
    if (snapshot.exists) {
      final Map<String, dynamic> raw = Map<String, dynamic>.from(snapshot.value as Map);

      final sortedKeys = raw.keys.toList()
        ..sort((a, b) => _parseDateTime(b).compareTo(_parseDateTime(a)));

      final latestKey = sortedKeys.first;
      final latest = Map<String, dynamic>.from(raw[latestKey]);

      setState(() {
        latestData = {
          'date': latestKey,
          'First_Pulse': extractValue(latest['First_Pulse']),
          'O2': extractValue(latest['O2']),
          'Temperature': extractValue(latest['Temperature']),
          'avgECG': averageFromMap(latest['ECG']),
          'avgStrain': averageFromMap(latest['Strain']),
        };
      });
    }
  }

  DateTime _parseDateTime(String dateStr) {
    try {
      final parts = dateStr.split(':');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
        int.parse(parts[3]),
        int.parse(parts[4]),
        int.parse(parts[5]),
      );
    } catch (e) {
      print('Ошибка парсинга даты: $e');
      return DateTime(1970); // fallback
    }
  }

  static dynamic extractValue(dynamic field) {
    if (field == null) return '—';

    if (field is List) {
      if (field.length > 1 && field[1] != null) return field[1];
      return '—';
    }

    if (field is Map && field.values.isNotEmpty) {
      final values = field.values.whereType<num>().toList();
      return values.isNotEmpty ? values.first : '—';
    }

    if (field is num || field is String) return field;

    return '—';
  }

  static double averageFromMap(dynamic data) {
    List<double> values = [];

    if (data is List) {
      values = data.whereType<num>().map((e) => e.toDouble()).toList();
    } else if (data is Map) {
      values = data.values.whereType<num>().map((e) => e.toDouble()).toList();
    }

    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Данные: ${widget.userId}")),
      body: latestData == null
          ? Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(title: Text("📅 Дата последней записи: ${latestData!['date']}")),
          ListTile(title: Text("❤️ First Pulse: ${latestData!['First_Pulse']}")),
          ListTile(title: Text("🫁 O2: ${latestData!['O2']}")),
          ListTile(title: Text("🌡 Температура: ${latestData!['Temperature']}")),
          ListTile(title: Text("📊 Среднее ECG: ${latestData!['avgECG'].toStringAsFixed(2)}")),
          ListTile(title: Text("🪶 Среднее Strain: ${latestData!['avgStrain'].toStringAsFixed(2)}")),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChartScreen(userId: widget.userId),
                ),
              );
            },
            child: Text("📈 Показать график"),
          ),
        ],
      ),
    );
  }
}



class ChartScreen extends StatefulWidget {
  final String userId;
  ChartScreen({required this.userId});

  @override
  _ChartScreenState createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final db = FirebaseDatabase.instance.ref();
  Map<String, dynamic> timeData = {};
  List<String> availableDates = [];
  String? selectedDate;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final snapshot = await db.child('${widget.userId}/time_data').get();
    if (snapshot.exists) {
      final raw = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        timeData = raw;
        availableDates = raw.keys
            .map((k) => k.split(':').take(3).join(':'))
            .toSet()
            .toList()
          ..sort((a, b) => _parseDate(a).compareTo(_parseDate(b)));
        isLoading = false;
      });
    }
  }

  DateTime _parseDate(String str) {
    final parts = str.split(':');
    return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  }

  DateTime _parseDateTime(String fullStr) {
    final parts = fullStr.split(':');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
      int.parse(parts[3]),
      int.parse(parts[4]),
      int.parse(parts[5]),
    );
  }

  List<FlSpot> generateSpots(String fieldName, double Function(double) normalizer) {
    if (selectedDate == null) return [];

    final filtered = timeData.entries
        .where((e) => e.key.startsWith(selectedDate!))
        .map((e) => MapEntry(_parseDateTime(e.key), Map<String, dynamic>.from(e.value)))
        .toList();

    final Map<int, double> valuePerSecond = {};
    for (var entry in filtered) {
      final secOfDay = entry.key.hour * 3600 + entry.key.minute * 60 + entry.key.second;
      final value = entry.value[fieldName];
      final v = _extractNumeric(value);
      valuePerSecond[secOfDay] = v;
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < 86400; i++) {
      final val = normalizer(valuePerSecond[i] ?? 0.0);
      spots.add(FlSpot(i.toDouble(), val));
    }

    return spots;
  }

  double _extractNumeric(dynamic value) {
    if (value == null) return 0.0;
    if (value is List && value.length > 1 && value[1] is num) return value[1].toDouble();
    if (value is Map && value.values.isNotEmpty) {
      final first = value.values.first;
      if (first is num) return first.toDouble();
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

  double getMaxValue(String fieldName) {
    if (selectedDate == null) return 1.0;

    final filtered = timeData.entries
        .where((e) => e.key.startsWith(selectedDate!))
        .map((e) => Map<String, dynamic>.from(e.value))
        .map((e) => _extractNumeric(e[fieldName]))
        .toList();

    final max = filtered.fold<double>(0.0, (a, b) => b > a ? b : a);
    return max > 0 ? max : 1.0;
  }

  Map<String, dynamic> calculateBreathingStats(List<double> strainSequence) {
    int breathCount = 0;
    List<int> pausesOver10s = [];
    List<int> pauses5to10s = [];
    int maxPause = 0;

    bool inBreath = false;
    int pauseLength = 0;
    List<int> pauseDurations = [];
    List<int> intervals = [];

    int lastInhaleIndex = -1;

    for (int i = 0; i < strainSequence.length; i++) {
      final val = strainSequence[i];

      if (val > 3300) {
        if (!inBreath) {
          breathCount++;
          inBreath = true;

          if (lastInhaleIndex != -1) {
            intervals.add(i - lastInhaleIndex);
          }
          lastInhaleIndex = i;
        }
        pauseLength = 0;
      } else {
        inBreath = false;
        pauseLength++;

        if (i == strainSequence.length - 1 || strainSequence[i + 1] > 3300) {
          if (pauseLength > 0) pauseDurations.add(pauseLength);
        }
      }
    }

    for (int p in pauseDurations) {
      if (p >= 10) {
        pausesOver10s.add(p);
      } else if (p >= 5) {
        pauses5to10s.add(p);
      }
      if (p > maxPause) maxPause = p;
    }

    double breathFreq = breathCount / (strainSequence.length / 60.0);
    double variability = intervals.isNotEmpty
        ? (intervals.reduce((a, b) => a + b) / intervals.length)
        : 0;

    return {
      'breathFreq': breathFreq,
      'variability': variability,
      'pauseCount10s': pausesOver10s.length,
      'maxPause': maxPause,
      'ahiIndex': pausesOver10s.length /
          (pauses5to10s.length == 0 ? 1 : pauses5to10s.length),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("\uD83D\uDCCA График за день")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          DropdownButton<String>(
            hint: Text("Выберите дату"),
            value: selectedDate,
            items: availableDates.map((date) {
              return DropdownMenuItem(
                child: Text(date.replaceAll(':', '.')),
                value: date,
              );
            }).toList(),
            onChanged: (value) {
              setState(() => selectedDate = value);
            },
          ),
          if (selectedDate != null)
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  buildChart("❤️ First Pulse", "First_Pulse", Colors.red),
                  buildChart("🫁 O2", "O2", Colors.blue),
                  buildChart("🌡 Temperature", "Temperature", Colors.orange),
                  ...buildBreathingStats(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> buildBreathingStats() {
    if (selectedDate == null) return [];

    final strainValues = List<double>.generate(86400, (i) => 0);

    timeData.entries.where((e) => e.key.startsWith(selectedDate!)).forEach((entry) {
      final time = _parseDateTime(entry.key);
      final second = time.hour * 3600 + time.minute * 60 + time.second;
      final data = Map<String, dynamic>.from(entry.value);
      final val = _extractNumeric(data['Strain']);
      strainValues[second] = val;
    });

    final stats = calculateBreathingStats(strainValues);

    return [
      SizedBox(height: 16),
      Text("\uD83D\uDCA8 Частота дыхания: ${stats['breathFreq'].toStringAsFixed(2)} вдохов/мин"),
      Text("\u2696\uFE0F Вариативность дыхания: ${stats['variability'].toStringAsFixed(2)} сек"),
      Text("⏸ Кол-во пауз >10с: ${stats['pauseCount10s']}"),
      Text("⏱ Макс. длительность паузы: ${stats['maxPause']} сек"),
      Text("📊 Индекс апное-гипное: ${stats['ahiIndex'].toStringAsFixed(2)}"),
    ];
  }

  Widget buildChart(String title, String fieldName, Color color) {
    final maxY = getMaxValue(fieldName);
    final spots = generateSpots(fieldName, (v) => v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                barWidth: 1.5,
                color: color,
                dotData: FlDotData(show: false),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 3600,
                  getTitlesWidget: (value, meta) {
                    final hour = (value / 3600).floor();
                    return Text('$hour:00', style: TextStyle(fontSize: 10));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toInt().toString(), style: TextStyle(fontSize: 10));
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: maxY / 4),
            borderData: FlBorderData(show: true),
          )),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

