import 'package:flutter/material.dart';
import 'package:kanban_board/kanban_board.dart';
import 'package:minute_meeting/models/kanban_group.dart'; // your KanbanItem import

class KanbanBoardPage extends StatefulWidget {
  @override
  _KanbanBoardPageState createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  final KanbanBoardController controller = KanbanBoardController();

  List<KanbanBoardGroup<String, KanbanItem>> groups = [

        KanbanBoardGroup<String, KanbanItem>(
      id: 'requested',
      name: 'Requested',
      items: [
 
      ],
    ),
    KanbanBoardGroup<String, KanbanItem>(
      id: 'todo',
      name: 'To Do',
      items: [
        KanbanItem(
          id: '1',
          title: 'Task 1',
          timestamp: DateTime.now().subtract(Duration(hours: 1)),
          createdBy: 'Alice',
        ),
        KanbanItem(
          id: '2',
          title: 'Task 2',
          timestamp: DateTime.now().subtract(Duration(days: 1, hours: 3)),
          createdBy: 'Bob',
        ),
      ],
    ),
    KanbanBoardGroup<String, KanbanItem>(
      id: 'in_progress',
      name: 'In Progress',
      items: [
        KanbanItem(
          id: '3',
          title: 'Task 3',
          timestamp: DateTime.now().subtract(Duration(hours: 1)),
          createdBy: 'Alice',
        ),
      ],
    ),
    KanbanBoardGroup<String, KanbanItem>(
      id: 'done',
      name: 'Done',
      items: [
        KanbanItem(
          id: '4',
          title: 'Task 4',
          timestamp: DateTime.now().subtract(Duration(hours: 1)),
          createdBy: 'Alice',
        ),
      ],
    ),
  ];

  int _taskIdCounter = 5;

  void _addNewTaskToGroup(String groupId, String title) {
    setState(() {
      groups = groups.map((group) {
        if (group.id == groupId) {
          return KanbanBoardGroup<String, KanbanItem>(
            id: group.id,
            name: group.name,
            items: [
              ...group.items,
              KanbanItem(
                id: _taskIdCounter.toString(),
                title: title,
                timestamp: DateTime.now(), // current time
                createdBy: 'User', // you can customize this
              ),
            ],
          );
        }
        return group;
      }).toList();
      _taskIdCounter++;
    });
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _showAddTaskDialog(String groupId) async {
    String newTaskTitle = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Task to ${groupId.toUpperCase()}'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter task title'),
          onChanged: (value) => newTaskTitle = value,
          onSubmitted: (value) {
            Navigator.of(context).pop();
            if (value.trim().isNotEmpty)
              _addNewTaskToGroup(groupId, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (newTaskTitle.trim().isNotEmpty)
                _addNewTaskToGroup(groupId, newTaskTitle.trim());
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kanban Board'),
      ),
      body: KanbanBoard(
        controller: controller,
        groups: groups,
        groupConstraints:
            const BoxConstraints(maxWidth: 200), // smaller width for columns
        groupHeaderBuilder: (context, groupId) {
          final group = groups.firstWhere((g) => g.id == groupId);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    group.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 20),
                  tooltip: 'Add Task',
                  onPressed: () => _showAddTaskDialog(group.id),
                ),
              ],
            ),
          );
        },

        groupItemBuilder: (context, groupId, itemIndex) {
          final item = groups
              .firstWhere((group) => group.id == groupId)
              .items[itemIndex];

          return ListTile(
            title:
                Text(item.title, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('Created by: ${item.createdBy}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                Text('Timestamp: ${_formatTimestamp(item.timestamp)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TaskDetailsPage(item: item),
              ));
            },
          );
        },
      ),
    );
  }
}

class TaskDetailsPage extends StatelessWidget {
  final KanbanItem item;
  TaskDetailsPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task ID: ${item.id}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Title: ${item.title}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Created by: ${item.createdBy}',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Timestamp: ${_formatTimestamp(item.timestamp)}',
                style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
