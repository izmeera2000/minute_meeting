import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class DotCalendarPage extends StatefulWidget {
  const DotCalendarPage({super.key});

  @override
  State<DotCalendarPage> createState() => _DotCalendarPageState();
}

class _DotCalendarPageState extends State<DotCalendarPage> {
  final _dbRef = FirebaseDatabase.instance.ref().child("calendarEvents");
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  final Set<String> _eventDates = {};
  final Map<String, Map<String, dynamic>> _eventMap = {};

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _fetchEvents() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        final Map<String, Map<String, dynamic>> eventMap = {};

        (data as Map).forEach((parentKey, childMap) {
          if (childMap is Map) {
            for (final value in childMap.values) {
              if (value is Map && value['status'] == 'Accepted' && value.containsKey('date')) {
                final dateStr = value['date'];
                if (dateStr != null) {
                  final date = DateTime.tryParse(dateStr);
                  if (date != null) {
                    final key = DateFormat('yyyy-MM-dd').format(date);
                    eventMap[key] = Map<String, dynamic>.from(value); // ✅ Fix type here
                  }
                }
              }
            }
          }
        });
        setState(() {
          _eventMap.clear();
          _eventMap.addAll(eventMap);
          _eventDates.clear();
          _eventDates.addAll(eventMap.keys);
        });
      }
    });
  }

  bool _hasEventOnDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return _eventDates.contains(key);
  }

  Future<void> _showMonthYearPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2050),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.red,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _focusedDate = DateTime(picked.year, picked.month);
      });
    }
  }

  TableRow _buildTableRow(List<DateTime?> weekDays) {
    return TableRow(
      children: weekDays.map((day) {
        if (day == null) {
          return Container(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
            ),
          );
        }

        final isSelected = day.year == _selectedDate.year &&
            day.month == _selectedDate.month &&
            day.day == _selectedDate.day;
        final hasEvent = _hasEventOnDay(day);

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = day),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              color: isSelected ? Colors.red.shade50 : Colors.white,
            ),
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.red : Colors.black,
                  ),
                ),
                const Spacer(),
                if (hasEvent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<TableRow> _buildCalendarRows() {
    DateTime firstDay = DateTime(_focusedDate.year, _focusedDate.month, 1);
    int firstWeekday = firstDay.weekday % 7;
    int daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;

    List<DateTime?> days = List.filled(firstWeekday, null, growable: true);
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(_focusedDate.year, _focusedDate.month, i + 1));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }

    List<TableRow> rows = [];
    for (int i = 0; i < days.length; i += 7) {
      rows.add(_buildTableRow(days.sublist(i, i + 7)));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dot Calendar View"),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
                  });
                },
              ),
              GestureDetector(
                onTap: _showMonthYearPicker,
                child: Text(
                  DateFormat.yMMMM().format(_focusedDate),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text("S", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("M", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("T", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("W", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("T", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("F", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("S", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Table(children: _buildCalendarRows()),
          const Divider(),
          Expanded(
            child: ListView(
              children: _eventMap.values
                  .where((e) {
                final d = DateTime.parse(e['date']);
                return d.year == _selectedDate.year &&
                    d.month == _selectedDate.month &&
                    d.day == _selectedDate.day;
              })
                  .map((e) => ListTile(
                title: Text(e['title'] ?? '-'),
                subtitle: Text(DateFormat('hh:mm a').format(DateTime.parse(e['date']))),
              ))
                  .toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Text("● Event", style: TextStyle(color: Colors.red)),
                Text("No Event", style: TextStyle(color: Colors.black54)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
