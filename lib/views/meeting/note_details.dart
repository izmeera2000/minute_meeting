// import 'package:flutter/material.dart';
// import 'package:minute_meeting/views/meeting/notes.dart';
 
// class MeetingNoteDetailsPage extends StatelessWidget {
//   final MeetingNote note;

//   const MeetingNoteDetailsPage({required this.note});

//   String _formatTimestamp(DateTime dt) =>
//       '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
//       '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(note.title)),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Author: ${note.author}', style: TextStyle(fontSize: 16)),
//             SizedBox(height: 4),
//             Text('Timestamp: ${_formatTimestamp(note.timestamp)}', style: TextStyle(fontSize: 16)),
//             SizedBox(height: 12),
//             Text('Content:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             SizedBox(height: 6),
//             Text(note.content, style: TextStyle(fontSize: 16)),
//           ],
//         ),
//       ),
//     );
//   }
// }
