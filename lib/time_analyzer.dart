import 'dart:io';
import 'dart:core';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
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
      _analyzeSuggestedTime(File file) async {
    // 1. 如果是图片，尝试从EXIF中提取创建时间
    if (isImageFile(file.path)) {
      final exifTime = await extractFromExif(file);
      if (exifTime != null) {
        return (exifTime, TimeAnalysisFrom.exif);
      }
    }

    // 2. 尝试从文件名中解析时间
    final filenameTime = extractFromName(file.path);
    if (filenameTime != null) {
      return (filenameTime, TimeAnalysisFrom.filename);
    }

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
      RegExp(r'(\d{4})(\d{2})(\d{2})[_-\s]?(\d{2}):(\d{2}):(\d{2})'),
      // YYYYMMDD_HHMMSS 格式，例如 "20120202_120000"
      // YYYYMMDDHHMMSS 格式，例如 "20120202120000"
      RegExp(r'(\d{4})(\d{2})(\d{2})[_-\s]?(\d{2})(\d{2})(\d{2})'),
      // YYYY-MM-DD 格式，例如 "2012-02-02",分隔符可以是“-" "/" "_" ":" “ ”
      RegExp(r'(\d{4})[-_:/\s](\d{2})[-_:/\s](\d{2})'),
      // YYYYMMDD 格式，例如 "20120202"
      RegExp(r'(\d{4})(\d{2})(\d{2})'),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(filename);
      if (match != null) {
        try {
          //显示所有匹配组，包括null值，自动判断匹配元素数量
          // final groups = List<String?>.generate(
          //     match.groupCount + 1, (i) => match.group(i));
          // logger.d('匹配组: $groups');

          if (match.groupCount >= 3) {
            int year, month, day, hour, minute, second;
            final yearStr = match.group(1);
            final monthStr = match.group(2);
            final dayStr = match.group(3);

            if (yearStr != null && monthStr != null && dayStr != null) {
              year = int.parse(yearStr);
              month = int.parse(monthStr);
              day = int.parse(dayStr);

              // 检查是否有时分秒信息
              if (match.groupCount >= 6) {
                hour = int.parse(match.group(4) ?? '00');
                minute = int.parse(match.group(5) ?? '00');
                second = int.parse(match.group(6) ?? '00');
              } else {
                hour = 0;
                minute = 0;
                second = 0;
              }

              if (isValidDateTime(
                  year: year,
                  month: month,
                  day: day,
                  hour: hour,
                  minute: minute,
                  second: second)) {
                final DateTime parsedTime =
                    DateTime(year, month, day, hour, minute, second);
                if (isValidDateRange(parsedTime)) {
                  return parsedTime;
                }
              }
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
    // logger.d('匹配 UNIX: ${matchUnix?.group(0)}');
    if (matchUnix != null) {
      final timestampStr = matchUnix.group(0) ?? '';
      final timestamp = int.parse(timestampStr);
      final DateTime parsedTime = DateTime.fromMillisecondsSinceEpoch(
          timestampStr.length == 10 ? timestamp * 1000 : timestamp);
      if (isValidDateRange(parsedTime)) {
        return parsedTime;
      }
    }

    return null;
  }

  /// 检查文件修改时间是否有问题
  /// 如果文件修改时间明显不合理（例如在1970年之前或未来很远的时间），则返回false
  static bool isValidDateRange(DateTime? time) {
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

  static bool isValidDateTime({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  }) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    if (hour < 0 || hour > 23) return false;
    if (minute < 0 || minute > 59) return false;
    if (second < 0 || second > 59) return false;
    if (millisecond < 0 || millisecond > 999) return false;
    if (microsecond < 0 || microsecond > 999) return false;

    return true;
  }

  /// 分析单个文件的时间状态，返回完整的分析结果
  /// 包含原始时间、建议时间、状态和分析方法
  static Future<TimeAnalysisResult> analyzeFile(File file) async {
    final DateTime originalTime = file.statSync().modified;
    final (DateTime? suggestedTime, TimeAnalysisFrom suggestedFrom) =
        await _analyzeSuggestedTime(file);
    TimeAnalysisStatus status = TimeAnalysisStatus.cannotJudge;

    // 尝试分析文件的创建时间并获取建议的修改时间
    if (suggestedTime == null) {
      status = TimeAnalysisStatus.cannotJudge;
    } else if (!isValidDateRange(suggestedTime)) {
      status = TimeAnalysisStatus.cannotJudge;
    } else if (suggestedTime.difference(originalTime).inMinutes.abs() > 1) {
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
