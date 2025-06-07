import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:minute_meeting/models/room.dart';
import 'package:minute_meeting/models/seed.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/settings/seed.dart';

class ManageRoom extends StatefulWidget {
  final String seedId;

  ManageRoom({required this.seedId});

  @override
  _ManageRoomState createState() => _ManageRoomState();
}

class _ManageRoomState extends State<ManageRoom> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;

  bool _isLoading = true;
  List<Seed> userSeeds = [];
  String? currentSeed; // currently selected seed ID

  List<Room> rooms = []; // <-- This must be List<Room>
  bool _isRoomsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserAndSeeds();
  }

  Future<void> _loadUserAndSeeds() async {
    final user = await UserModel.loadFromPrefs();
    if (user == null) return;

    setState(() {
      _currentUser = user;
      _isLoading = true;
    });

    // try {
    //   final userDoc = await _firestore.collection('users').doc(user.uid).get();

    //   if (!userDoc.exists) {
    //     setState(() {
    //       _isLoading = false;
    //     });
    //     return;
    //   }

    //   // Extract seeds from userDoc and convert each to a Seed model
    //   final seedsFromDoc =
    //       List<Map<String, dynamic>>.from(userDoc['seeds'] ?? []);

    //   final List<Seed> seedDetails = seedsFromDoc.map((seedMap) {
    //     // You may need to pass docId if available, else empty string
    //     final seedId = seedMap['seed'] ?? seedMap['seedId'] ?? '';
    //     final seedName = seedMap['name'] ?? '';

    //     return Seed(
    //       seedId: seedId,
    //       name: seedName,
    //       users: [], // You can fetch or fill users later if needed
    //     );
    //   }).toList();

    //   setState(() {
    //     userSeeds = seedDetails; // Assuming userSeeds is List<Seed>
    //     if (userSeeds.isNotEmpty) {
    //       currentSeed = userSeeds[0]
    //           .seedId; // or userSeeds[0] if you want full Seed object
    //     }
    //     _isLoading = false;
    //   });

    //   if (currentSeed != null) {
    _isLoading = false;

    _fetchRooms(widget.seedId); // Fetch rooms for the selected seed ID
    //   }
    // } catch (e) {
    //   print("Error loading seeds: $e");
    //   setState(() {
    //     _isLoading = false;
    //   });
    // }
  }

  Future<void> _fetchRooms(String seedId) async {
    setState(() {
      _isRoomsLoading = true;
      rooms = []; // Reset rooms list
    });

    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('seed', isEqualTo: seedId)
          .get();

      final fetchedRooms = snapshot.docs.map((doc) {
        return Room.fromMap(doc.id, doc.data());
      }).toList();

      setState(() {
        rooms = fetchedRooms;
        _isRoomsLoading = false;
      });

      print("Fetched rooms count: ${fetchedRooms.length}");
      for (var room in fetchedRooms) {
        print(
            'Room: ${room.roomId} - ${room.name} - Seed: ${room.seedId}');
        print(
            'Created At: ${room.createdAt?.toIso8601String()}'); // Debugging the createdAt field
      }
    } catch (e) {
      print("Error fetching rooms: $e");
      setState(() {
        _isRoomsLoading = false;
      });
    }
  }

  void _goToManageSeed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ManageSeed()),
    ).then((_) {
      // Reload seeds and rooms when returning from ManageSeed page
      _loadUserAndSeeds();
    });
  }

  void _addOrEditRoom({String? id, String? currentName, String? selectedSeed}) {
    final TextEditingController _controller =
        TextEditingController(text: currentName ?? '');

    String? selectedSeedId = selectedSeed ?? currentSeed;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text(id == null ? 'Add Room' : 'Edit Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(hintText: "Room Name"),
              ),
              SizedBox(height: 10),
              // DropdownButtonFormField<String>(
              //   decoration: InputDecoration(
              //     labelText: 'Select Seed',
              //     border: OutlineInputBorder(),
              //   ),
              //   value: selectedSeedId,
              //   onChanged: (newSeed) {
              //     setStateDialog(() {
              //       selectedSeedId = newSeed;
              //     });
              //   },
              //   items: userSeeds.map<DropdownMenuItem<String>>((seed) {
              //     return DropdownMenuItem<String>(
              //       value: seed['seedId'],
              //       child: Text(seed['name']),
              //     );
              //   }).toList(),
              //   isExpanded: true,
              // ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = _controller.text.trim();
                if (name.isNotEmpty) {
                  try {
                    if (id == null) {
                      DateTime createdAt = DateTime.now();

                      await _firestore.collection('rooms').add({
                        'name': name,
                        'seed': widget.seedId,
                        'created_at': createdAt,
                      });
                    } else {
                      await _firestore.collection('rooms').doc(id).update({
                        'name': name,
                        'seed': widget.seedId,
                      });
                    }
                    Navigator.pop(context);
                    _fetchRooms(widget.seedId);
                    // If seed changed, reload rooms for the selected seed
                    setState(() {
                      currentSeed = widget.seedId;
                    });
                  } catch (e) {
                    print("Error saving room: $e");
                  }
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      }),
    );
  }

  void _deleteRoom(String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).delete();
      if (currentSeed != null) {
        _fetchRooms(currentSeed!);
      }
    } catch (e) {
      print("Error deleting room: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Seed Selector Dropdown

          Expanded(
            child: _isRoomsLoading
                ? Center(child: CircularProgressIndicator())
                : rooms.isEmpty
                    ? Center(child: Text("No rooms found for this seed."))
                    : ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(room
                                  .name), // Use dot notation for Room properties
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _addOrEditRoom(
                                      id: room.roomId, // Room ID field
                                      currentName: room.name, // Room name field
                                      selectedSeed: room.seedId, // Assuming you want seedId here
                                    ),
                                    tooltip: "Edit Room",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteRoom(room.roomId),
                                    tooltip: "Delete Room",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.seedId == null
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: () => _addOrEditRoom(),
              child: Icon(Icons.add),
              tooltip: "Add Room",
            ),
    );
  }
}
