import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TaskflowApp());
}

class TaskflowApp extends StatelessWidget {
  const TaskflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskflow',
      home: TaskListPage(
        apiBase: const String.fromEnvironment(
          'API_BASE',
          defaultValue: 'http://127.0.0.1:8080',
        ),
      ),
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key, required this.apiBase});

  final String apiBase;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  late Future<List<dynamic>> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = _load();
  }

  Future<List<dynamic>> _load() async {
    final res = await http.get(Uri.parse('${widget.apiBase}/api/tasks'));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taskflow')),
      body: FutureBuilder<List<dynamic>>(
        future: _tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('offline (${snapshot.error})'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final task = tasks[i] as Map<String, dynamic>;
              final priority = task['priority']?.toString() ?? 'normal';
              return ListTile(
                title: Text('${task['title']}'),
                subtitle: Text('priority: $priority'),
              );
            },
          );
        },
      ),
    );
  }
}
