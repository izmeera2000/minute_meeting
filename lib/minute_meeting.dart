import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MinuteMeetingPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const MinuteMeetingPage({super.key, required this.event});

  @override
  State<MinuteMeetingPage> createState() => _MinuteMeetingPageState();
}

class _MinuteMeetingPageState extends State<MinuteMeetingPage> {
  final TextEditingController _minuteController = TextEditingController();
  bool _isSaving = false;
  String? eventKey;
  Map<String, bool> _attendanceStatus = {};

  @override
  void initState() {
    super.initState();
    _loadEventKeyMinuteAndAttendance();
  }

  void _loadEventKeyMinuteAndAttendance() async {
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
                          (k, v) => MapEntry(k, v == true),
                    ),
                  );
                } else {
                  final attendees = List<String>.from(subVal['attendees'] ?? []);
                  _attendanceStatus = {
                    for (var email in attendees) email: false
                  };
                }
              });
            }
          });
        }
      });
    }
  }

  void _saveMinuteAndAttendance() async {
    if (eventKey == null || _minuteController.text.isEmpty) return;

    setState(() => _isSaving = true);

    final ref = FirebaseDatabase.instance.ref().child('calendarEvents').child(eventKey!);
    final snapshot = await ref.get();

    // ✅ Get the logged-in user UID
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (snapshot.exists && uid != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      for (var entry in data.entries) {
        if (entry.key.startsWith('hour_')) {
          final match = entry.value['title'] == widget.event['title'] &&
              entry.value['date'] == widget.event['date'];

          if (match) {
            // ✅ Convert emails to Firebase-safe keys
            final safeAttendance = <String, bool>{};
            _attendanceStatus.forEach((email, value) {
              final safeKey = email.replaceAll('.', ',');
              safeAttendance[safeKey] = value;
            });

            // ✅ Save minute, attendance, and user ID
            await ref.child(entry.key).update({
              'minute': _minuteController.text,
              'attendance': safeAttendance,
              'recordedBy': uid, // 🔐 Insert the UID
            });
          }
        }
      }
    }

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Minute and attendance saved successfully")),
    );

    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Minute Meeting"),
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
                onTap: () async {
                  final updatedText = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditMinuteNotePage(
                        initialNote: _minuteController.text,
                      ),
                    ),
                  );
                  if (updatedText != null) {
                    setState(() {
                      _minuteController.text = updatedText;
                    });
                  }
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
                        ? "Write your meeting minutes here..."
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
                onChanged: (value) {
                  setState(() {
                    _attendanceStatus[email] = value ?? false;
                  });
                },
              )),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMinuteAndAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(_isSaving ? "Saving..." : "Save Minute"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class EditMinuteNotePage extends StatefulWidget {
  final String initialNote;

  const EditMinuteNotePage({super.key, required this.initialNote});

  @override
  State<EditMinuteNotePage> createState() => _EditMinuteNotePageState();
}

class _EditMinuteNotePageState extends State<EditMinuteNotePage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _controller.text);
            },
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          style: const TextStyle(fontSize: 16, height: 1.6),
          decoration: const InputDecoration(
            isCollapsed: true,
            hintText: "✍️ Start writing here...",
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none, // ❌ No border
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}