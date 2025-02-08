enum LogLevel {
  error,
  warning,
  info,
  debug,
}

extension LogLevelExtension on LogLevel {
  static const Map<LogLevel, String> _names = {
    LogLevel.error: 'ERROR',
    LogLevel.warning: 'WARN',
    LogLevel.info: 'INFO',
    LogLevel.debug: 'DEBUG',
  };

  String get name => _names[this] ?? 'UNKNOWN';
} 