import 'package:logger/logger.dart' as l;

/// Custom logger class to log messages with different levels to console.
class Logger {
  /// If this is set to true, debug messages will be printed.
  /// Otherwise, debug messages will be ignored and messages with other levels are printed.
  ///
  /// Default value is false.
  static bool enableDebug = false;

  /// Logger instance used to log messages.
  static final _logger = l.Logger(
    printer: LogPrinter(),
    filter: LogFilter(),
  );

  /// Print as Warning
  static warn(String message) {
    _logger.w('WARN: $message');
  }

  /// Print as error
  static error(dynamic message) {
    _logger.e('ERROR: $message');
  }

  /// Print as info
  static info(String message) {
    _logger.i('INFO: $message');
  }

  /// Print as debug
  static debug(String message) {
    _logger.d('DEBUG: $message');
  }

  /// Print without prefix
  static log(String message) {
    _logger.t(message);
  }
}

/// Customized log printer
class LogPrinter extends l.LogPrinter {
  @override
  List<String> log(l.LogEvent event) {
    // Get the color based on the level
    final color = l.PrettyPrinter.defaultLevelColors[event.level]!;
    final message = event.message;

    // Message format
    return [color(message)];
  }
}

/// Filter the log messages
class LogFilter extends l.LogFilter {
  @override
  bool shouldLog(l.LogEvent event) {
    return event.level != l.Level.debug || Logger.enableDebug;
  }
}
