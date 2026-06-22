import 'package:flutter/foundation.dart';

/// In-memory sink for the messages produced by the examples.
///
/// Entries are appended here so they can be shown in the app's activity log
/// view and copied by the user. They are also mirrored to the developer
/// console so the output stays available when a debugger is attached.
class ActivityLog extends ChangeNotifier {
  ActivityLog._();

  static final ActivityLog instance = ActivityLog._();

  final List<LogEntry> _entries = <LogEntry>[];

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  void add(String message) {
    final entry = LogEntry(DateTime.now(), message);
    _entries.add(entry);
    debugPrint(entry.toString());
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// The full log rendered as plain text, one entry per line.
  String asText() => _entries.map((LogEntry e) => e.toString()).join('\n');
}

/// A single timestamped activity log line.
class LogEntry {
  LogEntry(this.timestamp, this.message);

  final DateTime timestamp;
  final String message;

  @override
  String toString() {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final String ts = '${two(timestamp.hour)}:${two(timestamp.minute)}:'
        '${two(timestamp.second)}.${three(timestamp.millisecond)}';
    return '[$ts] $message';
  }
}

/// Convenience helper used throughout the examples in place of `print`.
void logLine(String message) => ActivityLog.instance.add(message);
