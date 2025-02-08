import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });
}

class LoggingService extends ChangeNotifier {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  late File _logFile;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory(path.join(appDir.path, 'logs'));
    
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    _logFile = File(path.join(logDir.path, 'wine_launcher.log'));
    _initialized = true;
  }

  void log(String message, {LogLevel level = LogLevel.info}) {
    _logs.add(LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    ));
    notifyListeners();
  }

  Future<void> logToFile(String message, {LogLevel level = LogLevel.info}) async {
    if (!_initialized) await init();
    
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp][${level.name.toUpperCase()}] $message\n';
    
    await _logFile.writeAsString(logMessage, mode: FileMode.append);
  }

  Future<String> getLogs() async {
    if (!_initialized) await init();
    return await _logFile.readAsString();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> clearLogs() async {
    if (!_initialized) await init();
    await _logFile.writeAsString('');
  }
}

enum LogLevel {
  error,
  warning,
  info,
  debug,
} 