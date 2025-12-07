import 'dart:io';
import 'dart:core';
import 'package:exif/exif.dart';
import 'logger_service.dart';

/// 时间分析状态枚举
enum TimeAnalysisStatus {
  consistent, // 时间一致，无需修正
  needsFix, // 需要修正时间
  cannotJudge // 无法判断
}

/// 时间分析方法枚举
enum TimeAnalysisFrom {
  exif, // 从EXIF中提取
  filename, // 从文件名中解析
  unknown // 未知方法
}

/// 时间分析结果类，用于存储文件的时间分析信息
class TimeAnalysisResult {
  final File file;
  final DateTime originalTime;
  final DateTime? suggestedTime;
  final TimeAnalysisStatus status;
  final TimeAnalysisFrom suggestedFrom;

  TimeAnalysisResult({
    required this.file,
    required this.originalTime,
    this.suggestedTime,
    required this.status,
    required this.suggestedFrom,
  });
}

/// 时间分析器，用于判断和修正文件的创建时间
class TimeAnalyzer {
  /// 分析文件的创建时间，并返回最佳的创建时间和分析方法
  /// 如果无法判断创建时间，则返回null和unknown方法
  static Future<(DateTime? suggestedTime, TimeAnalysisFrom suggestedFrom)>
      analyzeSuggestedTime(File file) async {
    // 1. 如果是图片，尝试从EXIF中提取创建时间
    if (isImageFile(file.path)) {
      final exifTime = await extractFromExif(file);
      if (exifTime != null && isTimeValid(exifTime)) {
        return (exifTime, TimeAnalysisFrom.exif);
      } else {}
    }

    // 2. 尝试从文件名中解析时间
    final filenameTime = extractFromName(file.path);
    if (filenameTime != null && isTimeValid(filenameTime)) {
      return (filenameTime, TimeAnalysisFrom.filename);
    }

    // 3. 尝试其他方法判断创建时间
    // 可以在这里添加更多的判断逻辑
    // 例如：检查文件内容中的时间信息等

    // 4. 无法判断创建时间
    return (null, TimeAnalysisFrom.unknown);
  }

  /// 判断文件是否为图片
  static bool isImageFile(String filePath) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.tiff',
      '.webp'
    ];
    final extension = filePath.toLowerCase().split('.').last;
    return imageExtensions.contains('.$extension');
  }

  /// 从图片EXIF信息中提取创建时间
  static Future<DateTime?> extractFromExif(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);

      // 常见的EXIF时间标签
      final timeTags = [
        'Image.DateTime',
        'Image.DateTimeOriginal',
        'Image.DateTimeDigitized',
        'EXIF.DateTimeOriginal',
        'EXIF.DateTimeDigitized',
        'EXIF DateTimeOriginal',
        'EXIF DateTimeDigitized',
      ];

      for (final tag in timeTags) {
        if (tags.containsKey(tag)) {
          final exifTime = tags[tag]?.printable;
          if (exifTime != null) {
            // EXIF时间格式通常为 "2023:10:05 14:30:45"
            try {
              // 只替换前两个冒号为短横线
              final formattedTime =
                  exifTime.replaceFirst(':', '-').replaceFirst(':', '-');
              return DateTime.parse(formattedTime);
            } catch (e) {
              // 解析失败，尝试其他标签
              continue;
            }
          }
        }
      }
    } catch (e) {
      // 无法读取EXIF信息或解析失败
      return null;
    }
    return null;
  }

  /// 从文件名中解析时间
  static DateTime? extractFromName(String filePath) {
    final filename = filePath.split(Platform.pathSeparator).last;

    // 支持的时间格式正则表达式
    final timePatterns = [
      // YYYY/MM/DD HH:MM:SS 格式，例如 "2012/02/02 12:00:00"
      // YYYY-MM-DD HH:MM:SS 格式，例如 "2012-02-02 12:00:00"
      // 分隔符可以是“-" "/" "_" ":"
      RegExp(
          r'(\d{4})[-\s/_:](\d{2})[-\s/_:](\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
      // YYYYMMDD HH:MM:SS 格式，例如 "20120202 12:00:00"
      // YYYYMMDD_HHMMSS 格式，例如 "20120202_120000"
      RegExp(r'(\d{4})(\d{2})(\d{2})\s?(\d{2}):(\d{2}):(\d{2})'),
      // YYYYMMDDHHMMSS 格式，例如 "20120202120000"
      RegExp(r'(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})'),
      // YYYYMMDD 格式，例如 "20120202"
      RegExp(r'(\d{4})(\d{2})(\d{2})'),
      // YYYY-MM-DD 格式，例如 "2012-02-02"
      RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
      // YYYY/MM/DD 格式，例如 "2012/02/02"
      RegExp(r'(\d{4})/(\d{2})/(\d{2})'),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(filename);
      if (match != null) {
        try {
          // 处理Unix时间戳
          final timestampStr = match.group(0) ?? '';
          if (timestampStr.length >= 10 && timestampStr.length <= 13) {
            logger.d('从文件名中解析到Unix时间戳: $timestampStr');
            final timestamp = int.parse(timestampStr);
            return DateTime.fromMillisecondsSinceEpoch(
                timestampStr.length == 10 ? timestamp * 1000 : timestamp);
          }

          // 处理其他时间格式
          if (match.groupCount >= 3) {
            final yearStr = match.group(1);
            final monthStr = match.group(2);
            final dayStr = match.group(3);

            if (yearStr != null && monthStr != null && dayStr != null) {
              final year = int.parse(yearStr);
              final month = int.parse(monthStr);
              final day = int.parse(dayStr);

              // 检查是否有时分秒信息
              if (match.groupCount >= 6) {
                final hourStr = match.group(4);
                final minuteStr = match.group(5);
                final secondStr = match.group(6);

                if (hourStr != null && minuteStr != null && secondStr != null) {
                  final hour = int.parse(hourStr);
                  final minute = int.parse(minuteStr);
                  final second = int.parse(secondStr);
                  return DateTime(year, month, day, hour, minute, second);
                }
              }

              // 没有时分秒或时分秒信息不完整，使用默认值
              return DateTime(year, month, day);
            }
          }
        } catch (e) {
          // 解析失败，尝试下一个模式
          continue;
        }
      }
    }

    // Unix时间戳（10位或13位）
    final matchUnix = RegExp(r'(\d{10,13})').firstMatch(filename);
    if (matchUnix != null) {
      final timestampStr = matchUnix.group(0) ?? '';
      logger.d('从文件名中解析到Unix时间戳: $timestampStr');
      final timestamp = int.parse(timestampStr);
      return DateTime.fromMillisecondsSinceEpoch(
          timestampStr.length == 10 ? timestamp * 1000 : timestamp);
    }
    
    return null;
  }

  /// 检查文件修改时间是否有问题
  /// 如果文件修改时间明显不合理（例如在1970年之前或未来很远的时间），则返回false
  static bool isTimeValid(DateTime? time) {
    if (time == null) {
      return false;
    }
    try {
      // 检查是否在合理的时间范围内
      // 1970年之前或2038年之后视为无效时间
      final minValidTime = DateTime(1970);
      final maxValidTime = DateTime(2038);

      return time.isAfter(minValidTime) && time.isBefore(maxValidTime);
    } catch (e) {
      // 无法获取文件状态，视为时间有问题
      return false;
    }
  }

  /// 分析并返回建议的文件修改时间
  /// 在Flutter中，我们无法直接修改文件的修改时间
  /// 需要使用平台特定的API来实现
  /// 返回建议的修改时间，如果无法判断则返回null
  // static Future<DateTime?> suggestFileModificationTime(File file) async {
  //   // 分析文件的创建时间
  //   final (DateTime? creationTime, TimeAnalysisFrom suggestedFrom) = await analyzeSuggestedTime(file);

  //   if (creationTime != null) {
  //     print('建议将文件 ${file.path} 的修改时间修正为: $creationTime');
  //     return creationTime;
  //   }

  //   print('无法判断文件 ${file.path} 的创建时间');
  //   return null;
  // }

  /// 分析单个文件的时间状态，返回完整的分析结果
  /// 包含原始时间、建议时间、状态和分析方法
  static Future<TimeAnalysisResult> analyzeFile(File file) async {
    final DateTime originalTime = file.statSync().modified;
    final (DateTime? suggestedTime, TimeAnalysisFrom suggestedFrom) =
        await analyzeSuggestedTime(file);
    TimeAnalysisStatus status = TimeAnalysisStatus.cannotJudge;

    // 尝试分析文件的创建时间并获取建议的修改时间
    if (suggestedTime == null) {
      status = TimeAnalysisStatus.cannotJudge;
    } else if (!isTimeValid(suggestedTime)) {
      status = TimeAnalysisStatus.cannotJudge;
    } else if (suggestedTime != originalTime) {
      status = TimeAnalysisStatus.needsFix;
    } else {
      status = TimeAnalysisStatus.consistent;
    }

    // 创建并返回时间分析结果
    return TimeAnalysisResult(
      file: file,
      originalTime: originalTime,
      suggestedTime: suggestedTime,
      suggestedFrom: suggestedFrom,
      status: status,
    );
  }
}
