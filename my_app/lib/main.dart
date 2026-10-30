import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

// ---------- Model ----------
class Task {
  final String id;
  final String title;
  final String category;
  final DateTime dueDate;
  final bool urgent;
  final double difficulty; // 1-5

  const Task({
    required this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.urgent,
    required this.difficulty,
  });
}

String formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

// ---------- App ----------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Tracker',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeShell(),
    );
  }
}

// ---------- Home: navigation + list state ----------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final List<Task> _tasks = [];
  int _tabIndex = 0;

  Future<void> _openForm({Task? existing}) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(existing: existing)),
    );
    // Guard: the widget may be gone after the await.
    if (!mounted || result == null) return;

    setState(() {
      final i = _tasks.indexWhere((t) => t.id == result.id);
      if (i == -1) {
        _tasks.add(result);
      } else {
        _tasks[i] = result;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? 'Task added' : 'Task updated')),
    );
  }

  Future<bool> _confirmDelete(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _remove(Task task) {
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Deleted "${task.title}"')));
  }

  Future<void> _longPressDelete(Task task) async {
    if (await _confirmDelete(task)) {
      if (!mounted) return;
      _remove(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TaskList(
        tasks: _tasks,
        onEdit: (t) => _openForm(existing: t),
        onLongPress: _longPressDelete,
        confirmDismiss: _confirmDelete,
        onDismissed: _remove,
      ),
      _TaskGrid(
        tasks: _tasks,
        onTap: (t) => _openForm(existing: t),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Task Tracker')),
      body: IndexedStack(index: _tabIndex, children: pages), // keeps tab state
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'List'),
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Grid'),
        ],
      ),
    );
  }
}

// ---------- Presentation widgets (Stateless) ----------
class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onEdit;
  final void Function(Task) onLongPress;
  final Future<bool> Function(Task) confirmDismiss;
  final void Function(Task) onDismissed;

  const _TaskList({
    required this.tasks,
    required this.onEdit,
    required this.onLongPress,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet. Tap "Add task".'));
    }
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        return Dismissible(
          key: ValueKey(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => confirmDismiss(task),
          onDismissed: (_) => onDismissed(task),
          child: TaskTile(
            task: task,
            onTap: () => onEdit(task),
            onLongPress: () => onLongPress(task),
          ),
        );
      },
    );
  }
}

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          task.urgent ? Icons.priority_high : Icons.check_circle_outline,
          color: task.urgent ? Colors.red : null,
        ),
        title: Text(task.title),
        subtitle: Text(
          '${task.category} • due ${formatDate(task.dueDate)} • '
          'difficulty ${task.difficulty.round()}/5',
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _TaskGrid extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onTap;

  const _TaskGrid({required this.tasks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('Nothing to show yet.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        return Card(
          child: InkWell(
            onTap: () => onTap(t),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text(t.category),
                  Text('Due ${formatDate(t.dueDate)}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Form screen (Stateful: owns the form values) ----------
class TaskFormScreen extends StatefulWidget {
  final Task? existing;
  const TaskFormScreen({super.key, this.existing});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  static const _categories = ['School', 'Work', 'Personal'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  String? _category;
  DateTime? _dueDate;
  bool _urgent = false;
  double _difficulty = 3;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _category = t?.category;
    _dueDate = t?.dueDate;
    _urgent = t?.urgent ?? false;
    _difficulty = t?.difficulty ?? 3;
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); // we created it, so we dispose it
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    if (!valid || _dueDate == null) {
      if (_dueDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please pick a due date')));
      }
      return;
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600)); // fake save
    if (!mounted) return; // guard after await

    Navigator.pop(
      context,
      Task(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        category: _category!,
        dueDate: _dueDate!,
        urgent: _urgent,
        difficulty: _difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New task' : 'Edit task'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
              validator: (v) => v == null ? 'Pick a category' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _dueDate == null
                    ? 'Pick due date'
                    : 'Due ${formatDate(_dueDate!)}',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Urgent'),
              value: _urgent,
              onChanged: (v) => setState(() => _urgent = v ?? false),
            ),
            const SizedBox(height: 8),
            Text('Difficulty: ${_difficulty.round()}/5'),
            Slider(
              value: _difficulty,
              min: 1,
              max: 5,
              divisions: 4,
              label: _difficulty.round().toString(),
              onChanged: (v) => setState(() => _difficulty = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
sout;