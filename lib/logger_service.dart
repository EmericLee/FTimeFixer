import 'package:logger/logger.dart';

/// 集中管理的日志工具类
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late final Logger _logger;

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal() {
    // 配置Logger
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 3,
        lineLength: 100,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
    );
  }

  /// 获取Logger实例
  Logger get logger => _logger;
}

/// 全局日志实例，方便直接使用
final Logger logger = LoggerService().logger;
