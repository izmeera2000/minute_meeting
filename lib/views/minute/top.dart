import 'package:flutter/material.dart';

class TwoTabsPage extends StatelessWidget {
  const TwoTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // number of tabs
      child: Scaffold(
        
        appBar: AppBar(
                  backgroundColor: Colors.red,
        foregroundColor: Colors.white,
          title: const Text('Two Tabs Example'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Tab 1'),
              Tab(icon: Icon(Icons.list), text: 'Tab 2'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Content for Tab 1')),
            Center(child: Text('Content for Tab 2')),
          ],
        ),
      ),
    );
  }
}
