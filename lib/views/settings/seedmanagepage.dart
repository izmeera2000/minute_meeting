import 'package:flutter/material.dart';
import 'package:minute_meeting/views/settings/room.dart';
import 'package:minute_meeting/views/settings/users.dart';

class TopNavigationPage extends StatefulWidget {


    final String seedId;
    final String title;

  TopNavigationPage({required this.seedId,required this.title});

  @override
  _TopNavigationPageState createState() => _TopNavigationPageState();
}

class _TopNavigationPageState extends State<TopNavigationPage> with TickerProviderStateMixin {
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String seedId = widget.seedId;



    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.red,
foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
                    indicatorColor: Colors.orange, // Change the color of the indicator
          labelColor: Colors.white,      // Change the color of the selected tab label
          unselectedLabelColor: Colors.grey, // Change the color of the unselected tab labels
          tabs: const [
            Tab(text: 'Room'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:   [
          ManageRoom(seedId:seedId),
          ManageUsers(seedId:seedId),
        ],
      ),
    );
  }
}