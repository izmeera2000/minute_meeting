import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:minute_meeting/viewminutemeetingpage.dart';

class MinuteMeetingListPage extends StatefulWidget {
  @override
  _MinuteMeetingListPageState createState() => _MinuteMeetingListPageState();
}

class _MinuteMeetingListPageState extends State<MinuteMeetingListPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('calendarEvents');
  List<Map<String, dynamic>> _minuteMeetings = [];
  bool _isLoading = true;
  String? currentUserEmail;

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndFetchMeetings();
  }

  Future<void> _getCurrentUserAndFetchMeetings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserEmail = user.email;
      _fetchMinuteMeetings();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fetchMinuteMeetings() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Map<String, dynamic>> loaded = [];

      data.forEach((eventKey, eventData) {
        if (eventData is Map) {
          eventData.forEach((subKey, subVal) {
            if (subKey.toString().startsWith('hour_') &&
                subVal is Map &&
                subVal.containsKey('minute')) {
              final List<String> attendees = List<String>.from(subVal['attendees'] ?? []);
              if (attendees.contains(currentUserEmail)) {
                final Map<String, dynamic> entry = Map<String, dynamic>.from(subVal);
                entry['eventKey'] = eventKey;
                loaded.add(entry);
              }
            }
          });
        }
      });

      setState(() {
        _minuteMeetings = loaded;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("My Minute Meetings"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _minuteMeetings.isEmpty
          ? Center(child: Text("No meetings found for you."))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: _minuteMeetings.map((meeting) {
            final title = meeting['title'] ?? '-';
            final date = meeting['date'] ?? '';
            final attendees = List<String>.from(meeting['attendees'] ?? []);
            final formattedDate = date.isNotEmpty
                ? DateFormat.yMMMMd().format(DateTime.parse(date))
                : '-';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewMinuteMeetingPage(event: meeting),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Title: $title",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text("Date: $formattedDate"),
                        SizedBox(height: 8),
                        Text("Attendees:", style: TextStyle(fontWeight: FontWeight.w500)),
                        ...attendees.map((email) => Text("- $email")),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
