import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class RoomManagementPage extends StatefulWidget {
  @override
  _RoomManagementPageState createState() => _RoomManagementPageState();
}

class _RoomManagementPageState extends State<RoomManagementPage> {
  final _dbRef = FirebaseDatabase.instance.ref().child('rooms');
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  void _fetchRooms() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final loaded = data.entries
          .map((entry) => {
        'key': entry.key,
        'name': entry.value['name'] ?? '',
      })
          .toList();
      setState(() {
        _rooms = loaded;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _addOrEditRoom({String? key, String? currentName}) {
    final TextEditingController _controller =
    TextEditingController(text: currentName ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(key == null ? 'Add Room' : 'Edit Room'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: "Room Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = _controller.text.trim();
              if (name.isNotEmpty) {
                if (key == null) {
                  await _dbRef.push().set({'name': name});
                } else {
                  await _dbRef.child(key).update({'name': name});
                }
                Navigator.pop(context);
                _fetchRooms();
              }
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteRoom(String key) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Room"),
        content: Text("Are you sure you want to delete this room?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _dbRef.child(key).remove();
              Navigator.pop(context);
              _fetchRooms();
            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Room Management"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
          ? Center(child: Text("No rooms added yet."))
          : ListView.builder(
        itemCount: _rooms.length,
        itemBuilder: (_, index) {
          final room = _rooms[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(room['name']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _addOrEditRoom(
                        key: room['key'], currentName: room['name']),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteRoom(room['key']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => _addOrEditRoom(),
        child: Icon(Icons.add),
      ),
    );
  }
}
