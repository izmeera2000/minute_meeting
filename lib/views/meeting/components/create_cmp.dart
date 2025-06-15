import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minute_meeting/helper/downloadpdf.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/views/meeting/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';












  String formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }
String getFileName(String url) {
  try {
    final segments = Uri.parse(url).pathSegments;
    final lastSegment = segments.isNotEmpty ? segments.last : 'unknown_file';
    
    // Split the filename by underscores and get the last part
    final nameParts = lastSegment.split('_');
    return nameParts.isNotEmpty ? nameParts.last : 'unknown_file';
  } catch (e) {
    return 'unknown_file';
  }
}


void launchURL(BuildContext context, String url) async {
  final fileName = getFileName(url);

  if (fileName.toLowerCase().endsWith('.pdf')) {
    // It's a PDF – download and view it
    try {
      final filePath = await downloadPdf(url, fileName);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewPage(filePath: filePath)),
      );
    } catch (e) {
      debugPrint('Error opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load PDF: $e')),
      );
    }
  } else {
    // Not a PDF – launch in external browser
    final uri = Uri.parse(url);
    try {
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('canLaunch: $canLaunch');
      if (!canLaunch) throw 'Cannot launch';

      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) debugPrint('Launch failed');
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}

Widget sectionTitle(String title, {String? buttonText, VoidCallback? onButtonPressed}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        if (buttonText != null && onButtonPressed != null)
          ElevatedButton(
            onPressed: onButtonPressed,
            child: Text(buttonText),
          ),
      ],
    ),
  );
}






class DateSectionCard extends StatelessWidget {
  final DateTime date;

  const DateSectionCard({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SizedBox(height: 6),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              DateFormat('yyyy-MM-dd').format(date),
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}


class TimeRangeCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const TimeRangeCard({
    super.key,
    required this.start,
    required this.end,
  });

  String formatDateTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          '${formatDateTime(start)} - ${formatDateTime(end)}',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }
}
class LocationCard extends StatelessWidget {
  final String location;

  const LocationCard({
    super.key,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          location,
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }
}
class CreatorCard extends StatelessWidget {
  final Creator creator;

  const CreatorCard({
    super.key,
    required this.creator,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          creator.name,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          creator.email,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }
}



