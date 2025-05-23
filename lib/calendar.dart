import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:minute_meeting/minute_meeting.dart'; // Make sure this is imported at the top

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _dbRef = FirebaseDatabase.instance.ref().child("calendarEvents");
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _events = [];
  List<String> _roomList = [];
  final ScrollController _suggestionScrollController = ScrollController();
  final GlobalKey firstSuggestionKey = GlobalKey();
  final Map<String, Color> _eventColorMap = {};

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchRooms();
  }

  void _fetchRooms() async {
    final roomSnapshot = await FirebaseDatabase.instance.ref().child('rooms').get();
    if (roomSnapshot.exists) {
      final roomData = Map<String, dynamic>.from(roomSnapshot.value as Map);
      final loadedRooms = roomData.values
          .map((value) => (value as Map)['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _roomList = loadedRooms;
      });
    }
  }

  void _fetchEvents() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        List<Map<String, dynamic>> loaded = [];
        (data as Map).forEach((parentKey, childMap) {
          if (childMap is Map) {
            childMap.forEach((_, value) {
              if (value is Map) {
                final eventItem = Map<String, dynamic>.from(value);
                eventItem['eventKey'] = parentKey;
                loaded.add(eventItem);
              }
            });
          }
        });
        setState(() {
          _events = loaded;
        });
      }
    });
  }


  Color _getEventColor(String eventKey) {
    if (_eventColorMap.containsKey(eventKey)) {
      return _eventColorMap[eventKey]!;
    } else {
      final Random random = Random(eventKey.hashCode);
      int base = 200;
      final color = Color.fromARGB(
        255,
        base + random.nextInt(56),
        base + random.nextInt(56),
        base + random.nextInt(56),
      );
      _eventColorMap[eventKey] = color;
      return color;
    }
  }


  void _showAddDialog() {
    final _titleController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Event"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: InputDecoration(labelText: 'Title')),
            ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (picked != null) selectedTime = picked;
              },
              child: Text("Select Time"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty && selectedTime != null) {
                final fullDateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );
                final newEvent = {
                  "title": _titleController.text,
                  "date": fullDateTime.toIso8601String(),
                };
                _dbRef.push().set(newEvent);
                Navigator.pop(context);
              }
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _eventsForSelectedDay {
    return _events.where((e) {
      final eventDate = DateTime.parse(e['date']);
      return eventDate.year == _selectedDate.year &&
          eventDate.month == _selectedDate.month &&
          eventDate.day == _selectedDate.day;
    }).toList();
  }

  Widget _buildHourRow(int hour) {
    final timeLabel = DateFormat.jm().format(DateTime(0, 0, 0, hour));
    final itemsAtThisHour = _eventsForSelectedDay
        .where((e) => DateTime.parse(e['date']).hour == hour)
        .toList();

    final hasAccepted = itemsAtThisHour.any((event) => (event['status'] ?? '') == 'Accepted');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: GestureDetector(
        onTap: () {
          if (itemsAtThisHour.isEmpty) {
            _showBookingDialog(hour);
          }
        },
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeLabel, style: TextStyle(fontSize: 13, color: Colors.red.shade300)),
                const SizedBox(height: 8),
                ...itemsAtThisHour.map((event) {
                  final eventKey = event['eventKey'] ?? '';
                  final bgColor = _getEventColor(eventKey);
                  final hasMinute = event.containsKey('minute') &&
                      (event['minute']?.toString().isNotEmpty ?? false);
                  final status = event['status'] ?? "Pending";

                  String labelText = "";
                  Color labelColor = Colors.blue;

                  if (status == "Pending") {
                    labelText = "Pending";
                    labelColor = Colors.orange;
                  } else if (status == "Rejected") {
                    labelText = "Rejected";
                    labelColor = Colors.red;
                  } else if (status == "Accepted") {
                    labelText = hasMinute ? "View Minute Meeting" : "Add Minute Meeting";
                    labelColor = Colors.blue;
                  }

                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'],
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: status == "Accepted"
                                ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MinuteMeetingPage(event: event),
                                ),
                              );
                            }
                                : null,
                            child: Text(
                              labelText,
                              style: TextStyle(color: labelColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // Show "Tap to book" only once at the end, and only if there's no Accepted
                if (!hasAccepted)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        _showBookingDialog(hour);
                      },
                      child: Text(
                        "Tap to book",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }





  Color _getRandomPastelColor() {
    final Random random = Random();
    int base = 200;
    return Color.fromARGB(
      255,
      base + random.nextInt(56),
      base + random.nextInt(56),
      base + random.nextInt(56),
    );
  }

  void _showBookingDialog(int hour) {
    final _titleController = TextEditingController();
    final _attendeeController = TextEditingController();
    final ScrollController _suggestionScrollController = ScrollController();
    String? _selectedRoom;
    String? _selectedDuration;
    final List<String> _durations = ['1 Hour', '2 Hours', '3 Hours', '4 Hours', '5 Hours'];
    List<String> _selectedAttendees = [];
    List<String> _allEmails = [];

    // Fetch registered user emails from Realtime Database
    FirebaseDatabase.instance.ref('users').once().then((snapshot) {
      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        _allEmails = data.values
            .map((u) => (u as Map)['email']?.toString() ?? '')
            .where((email) => email.isNotEmpty)
            .toList();
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            "Room Booking - ${DateFormat.jm().format(DateTime(0, 0, 0, hour))}",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Please select a room',
                  ),
                  value: _roomList.isNotEmpty ? _roomList.first : null,
                  items: _roomList.map((room) => DropdownMenuItem(value: room, child: Text(room))).toList(),
                  onChanged: (value) => setState(() => _selectedRoom = value),
                ),
                const SizedBox(height: 16),
                Text('Meeting Title', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter meeting title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Attendees (Email)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _attendeeController,
                  decoration: InputDecoration(
                    hintText: 'Search email and press Enter',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.isNotEmpty &&
                        !_selectedAttendees.contains(value) &&
                        _allEmails.contains(value)) {
                      setState(() {
                        _selectedAttendees.add(value);
                        _attendeeController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _selectedAttendees
                      .map((email) => Chip(
                    label: Text(email),
                    deleteIcon: Icon(Icons.close),
                    onDeleted: () => setState(() => _selectedAttendees.remove(email)),
                  ))
                      .toList(),
                ),
                if (_attendeeController.text.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 150),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView(
                        controller: _suggestionScrollController,
                        shrinkWrap: true,
                        children: _allEmails
                            .where((email) =>
                        email.toLowerCase().contains(_attendeeController.text.toLowerCase()) &&
                            !_selectedAttendees.contains(email))
                            .take(5)
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final email = entry.value;
                          final isFirst = index == 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Card(
                              key: isFirst ? firstSuggestionKey : null,
                              color: Colors.pink.shade50,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.add_circle_outline, color: Colors.red),
                                title: Text(email),
                                onTap: () {
                                  setState(() {
                                    _selectedAttendees.add(email);
                                    _attendeeController.clear();

                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final context = firstSuggestionKey.currentContext;
                                      if (context != null &&
                                          _suggestionScrollController.hasClients) {
                                        final box = context.findRenderObject() as RenderBox;
                                        final offset = box.localToGlobal(Offset.zero).dy;

                                        _suggestionScrollController.animateTo(
                                          _suggestionScrollController.offset + offset - 16,
                                          duration: Duration(milliseconds: 400),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    });
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Duration', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select duration',
                  ),
                  items: _durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (value) => setState(() => _selectedDuration = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                _selectedRoom ??= (_roomList.isNotEmpty ? _roomList.first : "Default Room");
                _selectedDuration ??= '1 Hour';

                if (_titleController.text.isNotEmpty) {
                  final int hoursToBook = int.tryParse(_selectedDuration!.split(' ').first) ?? 1;

                  try {
                    final newEventKey = _dbRef.push().key!;
                    final DatabaseReference eventRef = _dbRef.child(newEventKey);
                    final Map<String, dynamic> updates = {};

                    for (int i = 0; i < hoursToBook; i++) {
                      final eventDateTime = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        hour + i,
                      );

                      updates['hour_$i'] = {
                        "title": _titleController.text,
                        "date": eventDateTime.toIso8601String(),
                        "room": _selectedRoom,
                        "duration": '${hoursToBook} Hour${hoursToBook > 1 ? 's' : ''}',
                        "attendees": _selectedAttendees,
                        "status": "Pending"
                      };
                    }

                    print("📤 Writing to: /calendarEvents/$newEventKey");
                    print(updates);

                    await eventRef.set(updates);

                    print("✅ Firebase write success");

                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    print("🔥 Firebase write failed: $e");
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a meeting title.'),
                      backgroundColor: Colors.red,
                    ),
                  );                }
              }
              ,
              child: Text("Save Booking"),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _showMonthYearPicker() async {
    final now = DateTime.now();
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Month and Year'),
          content: SizedBox(
            height: 200,
            child: Column(
              children: [
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  onChanged: (value) {
                    setState(() {
                      selectedYear = value!;
                    });
                  },
                  items: List.generate(41, (index) {
                    int year = 2010 + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text('$year'),
                    );
                  }),
                ),
                DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  onChanged: (value) {
                    setState(() {
                      selectedMonth = value!;
                    });
                  },
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(DateFormat.MMMM().format(DateTime(0, index + 1))),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime(selectedYear, selectedMonth, 1);
                });
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final daysOfWeek = List.generate(7, (i) {
      final firstDayOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      return firstDayOfWeek.add(Duration(days: i));
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.EEEE().format(_selectedDate), style: TextStyle(color: Colors.black, fontSize: 16)),
            Text(DateFormat.yMMMMd().format(_selectedDate), style: TextStyle(color: Colors.black, fontSize: 13)),
          ],
        ),
        /*actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search, color: Colors.red)),
          IconButton(onPressed: _showAddDialog, icon: Icon(Icons.add, color: Colors.red)),
        ],

         */
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                    });
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2010),
                      lastDate: DateTime(2050),
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.red, // Header background color
                              onPrimary: Colors.white, // Header text color
                              onSurface: Colors.black, // Body text color
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  child: Text(
                    DateFormat.yMMMM().format(_selectedDate), // "May 2025"
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 7));
                    });
                  },
                ),
              ],
            ),
          ),

          SizedBox(
            height: 90,
            child: Row(
              children: List.generate(7, (index) {
                final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
                final day = weekStart.add(Duration(days: index));

                final isSelected = day.day == _selectedDate.day &&
                    day.month == _selectedDate.month &&
                    day.year == _selectedDate.year;

                final hasEvent = _events.any((event) {
                  final eventDate = DateTime.parse(event['date']);
                  return eventDate.year == day.year &&
                      eventDate.month == day.month &&
                      eventDate.day == day.day;
                });

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.E().format(day),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          if (hasEvent)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Divider(thickness: 1),
          Expanded(
            child: ListView.builder(
              itemCount: 12, // 8 AM to 8 PM
              itemBuilder: (_, i) => _buildHourRow(i + 8),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text("Today", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text("Calendars", style: TextStyle(color: Colors.red)),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text("Inbox", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
