import 'package:flutter/material.dart';
 import 'package:minute_meeting/views/settings/profile.dart';
import 'package:minute_meeting/views/settings/room.dart';
import 'package:minute_meeting/views/settings/seed.dart';
import 'package:minute_meeting/views/settings/users.dart'; // your KanbanItem import

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('Profile'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
          ),

                    ListTile(
            leading: Icon(Icons.group),
            title: Text('Group'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ManageSeed()),
              );
            },
          ),
          // ListTile(
          //   leading: Icon(Icons.room),
          //   title: Text('Rooms'),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => ManageRoom()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: Icon(Icons.group),
          //   title: Text('Users'),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => ManageUsers()),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }
}
