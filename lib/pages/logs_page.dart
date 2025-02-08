import 'package:flutter/material.dart';
import '../services/logging_service.dart';
import 'package:provider/provider.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text('Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      Provider.of<LoggingService>(context, listen: false).clear();
                    },
                    tooltip: 'Clear logs',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<LoggingService>(
                builder: (context, loggingService, _) {
                  if (loggingService.logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined, 
                            size: 64, 
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs available',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: loggingService.logs.length,
                    itemBuilder: (context, index) {
                      final log = loggingService.logs[index];
                      return Card(
                        color: _getLogBackgroundColor(log.level, isDark),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getLogIcon(log.level),
                                    size: 16,
                                    color: _getLogIconColor(log.level, isDark),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.timestamp.toString().split('.')[0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getLogTextColor(log.level, isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.level.toString().split('.')[1].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getLogTextColor(log.level, isDark),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                log.message,
                                style: TextStyle(
                                  color: _getLogTextColor(log.level, isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLogBackgroundColor(LogLevel level, bool isDark) {
    if (isDark) {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade900;
        case LogLevel.warning:
          return Colors.orange.shade900;
        case LogLevel.info:
          return Colors.blue.shade900;
        case LogLevel.debug:
          return Colors.grey.shade800;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade50;
        case LogLevel.warning:
          return Colors.orange.shade50;
        case LogLevel.info:
          return Colors.blue.shade50;
        case LogLevel.debug:
          return Colors.grey.shade100;
      }
    }
  }

  Color _getLogTextColor(LogLevel level, bool isDark) {
    if (isDark) {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade100;
        case LogLevel.warning:
          return Colors.orange.shade100;
        case LogLevel.info:
          return Colors.blue.shade100;
        case LogLevel.debug:
          return Colors.grey.shade300;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade900;
        case LogLevel.warning:
          return Colors.orange.shade900;
        case LogLevel.info:
          return Colors.blue.shade900;
        case LogLevel.debug:
          return Colors.grey.shade800;
      }
    }
  }

  Color _getLogIconColor(LogLevel level, bool isDark) {
    if (isDark) {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade200;
        case LogLevel.warning:
          return Colors.orange.shade200;
        case LogLevel.info:
          return Colors.blue.shade200;
        case LogLevel.debug:
          return Colors.grey.shade400;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade700;
        case LogLevel.warning:
          return Colors.orange.shade700;
        case LogLevel.info:
          return Colors.blue.shade700;
        case LogLevel.debug:
          return Colors.grey.shade700;
      }
    }
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.debug:
        return Icons.bug_report_outlined;
    }
  }
} 