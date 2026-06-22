import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity_log.dart';
import 'examples/sep_001.dart' as sep01_example;
import 'examples/sep_010.dart' as sep10_example;
import 'examples/sep_024.dart' as sep24_example;
import 'examples/sep_030.dart' as sep30_example;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Wallet Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'Flutter Wallet SDK Demo'),
    );
  }
}

/// Describes a runnable example shown as a button in the UI.
class _Example {
  const _Example(this.name, this.run);

  final String name;
  final Future<void> Function() run;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ActivityLog _log = ActivityLog.instance;
  final ScrollController _logScrollController = ScrollController();

  /// Names of the examples that are currently running.
  final Set<String> _running = <String>{};

  static const List<_Example> _examples = <_Example>[
    _Example('SEP-001', sep01_example.runExample),
    _Example('SEP-010', sep10_example.runExample),
    _Example('SEP-024', sep24_example.runExample),
    _Example('SEP-030', sep30_example.runExample),
  ];

  @override
  void initState() {
    super.initState();
    _log.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    _log.removeListener(_onLogChanged);
    _logScrollController.dispose();
    super.dispose();
  }

  void _onLogChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    // Keep the newest entry visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController
            .jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _runExample(_Example example) async {
    if (_running.contains(example.name)) {
      return;
    }
    setState(() => _running.add(example.name));
    logLine('--- ${example.name} started ---');
    try {
      await example.run();
      logLine('--- ${example.name} finished ---');
    } catch (e, stackTrace) {
      logLine('${example.name} failed: $e');
      logLine(stackTrace.toString());
    } finally {
      if (mounted) {
        setState(() => _running.remove(example.name));
      }
    }
  }

  Future<void> _copyLog() async {
    await Clipboard.setData(ClipboardData(text: _log.asText()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activity log copied to clipboard')),
    );
  }

  void _clearLog() {
    _log.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasEntries = !_log.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildExamplesSection(),
          const Divider(height: 1),
          _buildLogHeader(hasEntries),
          const Divider(height: 1),
          Expanded(child: _buildLogView()),
        ],
      ),
    );
  }

  Widget _buildExamplesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Examples', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examples.map(_buildExampleButton).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleButton(_Example example) {
    final bool isRunning = _running.contains(example.name);
    return ElevatedButton(
      onPressed: isRunning ? null : () => _runExample(example),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isRunning) ...<Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Text(example.name),
        ],
      ),
    );
  }

  Widget _buildLogHeader(bool hasEntries) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Text('Activity Log', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy),
            onPressed: hasEntries ? _copyLog : null,
          ),
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_outline),
            onPressed: hasEntries ? _clearLog : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLogView() {
    if (_log.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No activity yet. Tap an example above to run it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E1E),
      child: Scrollbar(
        controller: _logScrollController,
        child: SingleChildScrollView(
          controller: _logScrollController,
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            _log.asText(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
              color: Color(0xFFE0E0E0),
            ),
          ),
        ),
      ),
    );
  }
}
