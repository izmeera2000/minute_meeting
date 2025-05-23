import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ViewMinuteMeetingPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const ViewMinuteMeetingPage({super.key, required this.event});

  @override
  State<ViewMinuteMeetingPage> createState() => _ViewMinuteMeetingPageState();
}

class _ViewMinuteMeetingPageState extends State<ViewMinuteMeetingPage> {
  final TextEditingController _minuteController = TextEditingController();
  String? eventKey;
  Map<String, bool> _attendanceStatus = {};

  @override
  void initState() {
    super.initState();
    _loadMinuteAndAttendance();
  }

  void _loadMinuteAndAttendance() async {
    final ref = FirebaseDatabase.instance.ref().child('calendarEvents');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          value.forEach((subKey, subVal) {
            if (subVal is Map &&
                subVal['title'] == widget.event['title'] &&
                subVal['date'] == widget.event['date']) {
              setState(() {
                eventKey = key;
                if (subVal.containsKey('minute')) {
                  _minuteController.text = subVal['minute'];
                }
                if (subVal.containsKey('attendance')) {
                  _attendanceStatus = Map<String, bool>.from(
                    (subVal['attendance'] as Map).map(
                          (k, v) => MapEntry(k.replaceAll(',', '.'), v == true),
                    ),
                  );
                } else {
                  final attendees = List<String>.from(subVal['attendees'] ?? []);
                  _attendanceStatus = {
                    for (var email in attendees) email: false,
                  };
                }
              });
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("View Minute Meeting"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: eventKey == null
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Meeting Title:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(widget.event['title']),
              ),
              const SizedBox(height: 20),
              Text("Minute Notes:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewMinuteNotePage(note: _minuteController.text),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Text(
                    _minuteController.text.isEmpty
                        ? "No minute note recorded."
                        : _minuteController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: _minuteController.text.isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text("Attendance:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ..._attendanceStatus.keys.map((email) => CheckboxListTile(
                title: Text(email),
                value: _attendanceStatus[email],
                onChanged: null, // ✅ Disable editing
              )),
            ],
          ),
        ),
      ),
    );
  }
}


class ViewMinuteNotePage extends StatelessWidget {
  final String note;

  const ViewMinuteNotePage({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "Minute Meeting Notes",
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          note.isEmpty ? "No note recorded." : note,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
      ),
    );
  }
}