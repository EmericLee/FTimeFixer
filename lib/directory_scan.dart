import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logger_service.dart';
import 'time_analyzer.dart';
import 'notification_service.dart';

/// 目录列表页面（为了向后兼容而保留）
class DirectoryListPage extends StatelessWidget {
  const DirectoryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目录列表'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const DirectoryListWidget(),
    );
  }
}

/// 目录列表 Widget，可复用的文件浏览器组件
class DirectoryListWidget extends StatefulWidget {
  /// 可选参数：初始选中的目录路径
  final String? initialDirectory;

  /// 可选参数：是否自动扫描初始目录
  final bool autoScanInitialDirectory;

  /// 可选参数：回调函数，当文件列表更新时触发
  final ValueChanged<List<File>>? onFileListUpdated;

  const DirectoryListWidget({
    super.key,
    this.initialDirectory,
    this.autoScanInitialDirectory = false,
    this.onFileListUpdated,
  });

  @override
  State<DirectoryListWidget> createState() => _DirectoryListWidgetState();
}

class _DirectoryListWidgetState extends State<DirectoryListWidget> {
  String? _selectedDirectory;
  List<File> _fileList = [];
  bool _isScanning = false;
  List<TimeAnalysisResult> _fileListTimeAnalysised = [];
  bool _isTimeAnalysising = false;
  int _fileCount = 0;
  int _firstVisibleIndex = 0;
  final ScrollController _scrollController = ScrollController();

  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void onPressed() {}

  @override
  void initState() {
    super.initState();

    // 处理初始目录
    if (widget.initialDirectory != null) {
      _selectedDirectory = widget.initialDirectory;
      if (widget.autoScanInitialDirectory) {
        _directoryScan(widget.initialDirectory!);
      }
    }

    // 监听滚动位置
    _scrollController.addListener(() {
      final firstVisibleIndex =
          _scrollController.position.minScrollExtent == _scrollController.offset
              ? 0
              : (_scrollController.offset /
                      _scrollController.position.maxScrollExtent *
                      _fileList.length)
                  .floor();

      if (firstVisibleIndex != _firstVisibleIndex) {
        setState(() {
          _firstVisibleIndex = firstVisibleIndex;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //header directory info
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _directorySelect,
                child: const Text('选择目录'),
              ),
              const SizedBox(width: 20), // 横向间距

              Expanded(
                child: Text(
                  _selectedDirectory != null
                      ? '选中目录: $_selectedDirectory'
                      : '请选择目录',
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isScanning) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('发现文件： $_fileCount '),
                      const SizedBox(width: 8),
                    ],
                    if (_fileList.isNotEmpty &&
                        _fileListTimeAnalysised.isEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '发现文件 $_fileCount 个',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_isTimeAnalysising) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已分析 ${_fileListTimeAnalysised.length} / $_fileCount ',
                      ),
                    ],
                    if (!_isTimeAnalysising &&
                        _fileListTimeAnalysised.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      Text(
                        '分析完成 ${_fileListTimeAnalysised.length} 文件',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message:
                            'EXIF: ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.consistent && r.suggestedFrom == TimeAnalysisFrom.exif).length}'
                            ' NAME: ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.consistent && r.suggestedFrom == TimeAnalysisFrom.filename).length})',
                        child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              // fixedSize: const Size(100, 24), // 固定宽高
                              minimumSize: const Size(60, 30), // 控制最小宽高
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              textStyle: const TextStyle(fontSize: 10),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            onPressed: onPressed,
                            label: Text(
                                "一致 ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.consistent).length}")),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message:
                            ' EXIF: ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.needsFix && r.suggestedFrom == TimeAnalysisFrom.exif).length}'
                            ' FILE: ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.needsFix && r.suggestedFrom == TimeAnalysisFrom.filename).length})',
                        child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              // fixedSize: const Size(100, 24), // 固定宽高
                              minimumSize: const Size(60, 30), // 控制最小宽高
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              textStyle: const TextStyle(fontSize: 10),
                            ),
                            icon: const Icon(Icons.timer, size: 16),
                            onPressed: onPressed,
                            label: Text(
                                "修正 ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.needsFix).length}'")),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: '',
                        // child: Text(
                        //     ' 无法解析：${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.cannotJudge).length}'),
                        child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              // fixedSize: const Size(100, 24), // 固定宽高
                              minimumSize: const Size(60, 30), // 控制最小宽高
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              textStyle: const TextStyle(fontSize: 10),
                            ),
                            icon:
                                const Icon(Icons.image_not_supported, size: 16),
                            onPressed: onPressed,
                            label: Text(
                                "无法解析 ${_fileListTimeAnalysised.where((r) => r.status == TimeAnalysisStatus.cannotJudge).length}")),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        ),

        //separator
        const Divider(height: 1),

        // 文件列表
        Expanded(
          child: Column(
            children: [
              Expanded(
                  child: _fileList.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('请选择一个目录',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 8),
                              Text('点击上方按钮选择要扫描的目录',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        )
                      : _buildFileList()),
              // 底部信息栏
              if (_fileList.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('总计: $_fileCount 个文件'),
                      Text(
                          '当前位置: ${_firstVisibleIndex + 1}/${_fileList.length}'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 构建文件列表视图
  Widget _buildFileList() {
    if (_fileList.isEmpty) {
      return const Center(child: Text('请选择一个目录'));
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _fileList.length,
        // 使用separated更高效地添加分隔线
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          File file = _fileList[index];
          TimeAnalysisResult? analysisResult;

          // 查找当前文件的时间分析结果
          if (index < _fileListTimeAnalysised.length) {
            analysisResult = _fileListTimeAnalysised[index];
          }

          return _buildFileListRow(file, analysisResult);
        },
      ),
    );
  }

  // 构建文件列表项 row
  Widget _buildFileListRow(File file, TimeAnalysisResult? analysisResult) {
    return ListTile(
      leading: const Icon(Icons.insert_drive_file, size: 20),
      title: Row(
        children: [
          Flexible(
            child: SelectableText(
              file.path.split(Platform.pathSeparator).last,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: SelectableText(
        file.path,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: SizedBox(
        width: 200, // 设置固定宽度以控制右侧显示区域
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 原始修改时间（trailing显示）
            _buildFileOrignalTime(file, analysisResult),
            // 分析结果（trailing显示）
            _buildFileAnalyTime(analysisResult)
          ],
        ),
      ),
    );
  }

  // 获取状态图标和文本
  Widget _buildFileAnalyTime(TimeAnalysisResult? result) {
    SelectableText msgText;
    Icon msgIcon;

    if (result == null) {
      msgText = const SelectableText('正在分析...');
      msgIcon = const Icon(Icons.help, size: 12, color: Colors.grey);
    } else {
      switch (result.status) {
        case TimeAnalysisStatus.consistent:
          msgText =
              SelectableText('一致 ${_formatDateTime(result.suggestedTime)}');
          msgIcon =
              const Icon(Icons.check_circle, size: 12, color: Colors.green);
          break;
        case TimeAnalysisStatus.needsFix:
          msgText =
              SelectableText('需要修正: ${_formatDateTime(result.suggestedTime)}');
          msgIcon = const Icon(Icons.warning, size: 12, color: Colors.orange);
          break;
        case TimeAnalysisStatus.cannotJudge:
          msgText = SelectableText(
              '无有效时间信息： ${_formatDateTime(result.suggestedTime)}');
          msgIcon = const Icon(Icons.help, size: 12, color: Colors.grey);
          break;
      }
      switch (result.suggestedFrom) {
        case TimeAnalysisFrom.exif:
          msgText = SelectableText('${msgText.data ?? ''} (E)');
          break;
        case TimeAnalysisFrom.filename:
          msgText = SelectableText('${msgText.data ?? ''} (F)');
          break;
        case TimeAnalysisFrom.unknown:
          msgText = SelectableText('${msgText.data ?? ''} (U)');
          break;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        msgIcon,
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            msgText.data ?? '',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 构建文件原始信息行
  Widget _buildFileOrignalTime(File file, TimeAnalysisResult? analysisResult) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.history, size: 12, color: Colors.blue),
        const SizedBox(width: 2),
        SelectableText(
          analysisResult != null
              ? _formatDateTime(analysisResult.originalTime)
              : _formatDateTime(file.statSync().modified),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  // 检查并请求存储权限
  Future<bool> _checkAndroidStoragePermission() async {
    // 根据Android版本检查不同的权限
    if (Platform.isAndroid) {
      // Android 13+ (API 33+)
      if (await Permission.storage.status.isDenied ||
          await Permission.photos.status.isDenied ||
          await Permission.videos.status.isDenied ||
          await Permission.audio.status.isDenied) {
        // 请求Android 13+的媒体权限
        Map<Permission, PermissionStatus> statuses = await [
          Permission.storage,
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();

        // 检查是否有必要的权限被授予
        return statuses[Permission.storage]?.isGranted == true ||
            statuses[Permission.photos]?.isGranted == true ||
            statuses[Permission.videos]?.isGranted == true ||
            statuses[Permission.audio]?.isGranted == true;
      }

      // Android 11-12 (API 30-32)
      if (await Permission.storage.status.isDenied) {
        if (await Permission.storage.request().isGranted) {
          return true;
        }
      }

      // Android 10 及以下
      if (await Permission.manageExternalStorage.status.isDenied) {
        if (await Permission.manageExternalStorage.request().isGranted) {
          return true;
        }
      }
    }

    // 非Android平台或已拥有权限
    return true;
  }

  // 选择目录并开始扫描
  Future<void> _directorySelect() async {
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        // notification.show(msg: '已经选择目录 $directoryPath \n 开始扫描...');
        _directoryScan(directoryPath);
      } else {
        notification.show(msg: '未选择目录，请重新选择...');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      notification.show(msg: '选择目录时出错: $e');
    }
  }

  // 开始扫描目录
  Future<void> _directoryScan(String directoryPath) async {
    // 检查权限
    bool hasPermission = await _checkAndroidStoragePermission();
    if (!hasPermission) {
      setState(() {
        _isScanning = false;
      });
      // 检查组件是否仍然挂载，避免在异步操作后使用已销毁的context
      notification.show(msg: '需要存储权限才能访问文件');
      return;
    }

    // 初始化扫描状态
    setState(() {
      _selectedDirectory = directoryPath;
      _isScanning = true;
      _fileList.clear();
      _fileListTimeAnalysised.clear();
      _fileCount = 0;
    });

    // 扫描目录列表
    await _directoryScanList(directoryPath);

    // notification.show(title: '扫描完成', msg: '已扫描 ${_fileList.length} 个文件');

    setState(() {
      _isScanning = false;
      // 按文件名字母排序
      _fileCount = _fileList.length;
    });

    // 扫描完成后，检查并修正文件修改时间
    safeSetState(() {
      _isTimeAnalysising = true;
    });

    await _directoryScanTime();

    safeSetState(() {
      _isTimeAnalysising = false;
    });

    // 调用文件列表更新回调
    widget.onFileListUpdated?.call(_fileList);
  }

  // 递归扫描目录
  Future<void> _directoryScanList(String directoryPath) async {
    Directory directory = Directory(directoryPath);
    final List<File> files = [];

    if (!directory.existsSync()) {
      logger.w('目录不存在: $directoryPath');
      return;
    }

    try {
      // 使用异步方式获取目录实体，避免阻塞UI线程
      Stream<FileSystemEntity> entityStream =
          directory.list(recursive: true, followLinks: false);

      await for (var entity in entityStream) {
        // 暂停10毫秒，避免UI卡顿
        // await Future.delayed(const Duration(milliseconds: 2));

        try {
          if (entity is File) {
            // 检查文件是否可读
            if (entity.existsSync() && await entity.length() >= 0) {
              // 确保组件仍然处于挂载状态，避免setState() called after dispose()错误
              files.add(entity);
            }
          }
        } catch (fileError) {
          // 忽略单个文件的错误，继续扫描其他文件
          logger.e('访问文件时出错: ${entity.path}, 错误: $fileError');
        }

        //update file count every 10 files
        int count = files.length;
        if ((count + 1) % 10 == 0) {
          safeSetState(() {
            _fileCount = files.length;
          });
        }
      }

      //update file list
      files.sort((a, b) => a.path.compareTo(b.path));
      safeSetState(() {
        _fileCount = files.length;
        _fileList = files;
      });
    } catch (e) {
      // 记录详细的目录扫描错误
      logger.e('扫描目录时出错: $directoryPath, 错误: $e');

      // 在Android平台上，可能需要特殊处理分区存储限制
      if (Platform.isAndroid) {
        logger.w('Android平台上的目录访问错误，可能是因为分区存储限制');
        // 尝试访问应用私有目录作为替代方案
        try {
          String? appDir = Directory.systemTemp.parent.path;
          logger.i('尝试访问应用目录: $appDir');
          Directory appDirectory = Directory(appDir);
          if (appDirectory.existsSync()) {
            Stream<FileSystemEntity> appEntityStream =
                appDirectory.list(recursive: true, followLinks: false);

            await for (var entity in appEntityStream) {
              if (entity is File) {
                // 确保组件仍然处于挂载状态，避免setState() called after dispose()错误
                if (mounted) {
                  setState(() {
                    _fileList.add(entity);
                  });
                }
              }
            }
          }
        } catch (appDirError) {
          logger.e('访问应用目录时出错: $appDirError');
        }
      }
    }
  }

  // 检查并分析文件的修改时间
  Future<void> _directoryScanTime() async {
    if (_fileList.isEmpty) {
      return;
    }

    List<TimeAnalysisResult> results = [];

    // 遍历所有文件
    for (int i = 0; i < _fileList.length; i++) {
      final file = _fileList[i];

      // await Future.delayed(const Duration(milliseconds: 10));

      // 使用TimeAnalyzer.analyzeSingleFile方法获取分析结果
      final result = await TimeAnalyzer.analyzeFile(file);
      results.add(result);

      // 显示进度信息
      if (i % 10 == 0) {
        // 更新时间分析结果列表
        safeSetState(() {
          _fileListTimeAnalysised = results;
        });
      }
    }

    safeSetState(() {
      _fileListTimeAnalysised = results;
    });

    // // 显示检查结果
    // final message = '文件时间检查完成: 总计 ${_fileList.length} 个文件\n'
    //     ' 时间一致：${results.where((r) => r.status == TimeAnalysisStatus.consistent).length}\n'
    //     '      EXIF解析：${results.where((r) => r.status == TimeAnalysisStatus.consistent && r.suggestedFrom == TimeAnalysisFrom.exif).length}\n'
    //     '      文件名解析：${results.where((r) => r.status == TimeAnalysisStatus.consistent && r.suggestedFrom == TimeAnalysisFrom.filename).length}\n'
    //     ' 需要修正：${results.where((r) => r.status == TimeAnalysisStatus.needsFix).length}\n'
    //     '      EXIF解析：${results.where((r) => r.status == TimeAnalysisStatus.needsFix && r.suggestedFrom == TimeAnalysisFrom.exif).length}\n'
    //     '      文件名解析：${results.where((r) => r.status == TimeAnalysisStatus.needsFix && r.suggestedFrom == TimeAnalysisFrom.filename).length}\n'
    //     ' 无法解析时间：${results.where((r) => r.status == TimeAnalysisStatus.cannotJudge).length}\n'
    //     '---------------------------';

    // notification.show(title: '扫描完成', msg: message, persistent: true);
  }

  // 格式化日期时间
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';
  }

  // 格式化两位数
  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
}
