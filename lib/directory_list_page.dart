import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// 目录列表 Widget，可复用的文件浏览器组件
class DirectoryListWidget extends StatefulWidget {
  /// 可选参数：初始选中的目录路径
  final String? initialDirectory;

  /// 可选参数：是否自动扫描初始目录
  final bool autoScanInitialDirectory;

  /// 可选参数：回调函数，当选择目录时触发
  final ValueChanged<String>? onDirectorySelected;

  /// 可选参数：回调函数，当文件列表更新时触发
  final ValueChanged<List<File>>? onFileListUpdated;

  const DirectoryListWidget({
    Key? key,
    this.initialDirectory,
    this.autoScanInitialDirectory = false,
    this.onDirectorySelected,
    this.onFileListUpdated,
  }) : super(key: key);

  @override
  State<DirectoryListWidget> createState() => _DirectoryListWidgetState();
}

class _DirectoryListWidgetState extends State<DirectoryListWidget> {
  String? _selectedDirectory;
  List<File> _fileList = [];
  bool _isScanning = false;
  int _fileCount = 0;
  int _firstVisibleIndex = 0;
  final ScrollController _scrollController = ScrollController();

  // 选择目录
  Future<void> _selectDirectory() async {
    try {
      String? result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _startScan(result);
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择目录时出错: $e')),
      );
    }
  }

  // 检查并请求存储权限
  Future<bool> _checkStoragePermission() async {
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

  // 开始扫描目录
  Future<void> _startScan(String directoryPath) async {
    // 检查权限
    bool hasPermission = await _checkStoragePermission();
    if (!hasPermission) {
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要存储权限才能访问文件')),
      );
      return;
    }
    
    setState(() {
      _selectedDirectory = directoryPath;
      _isScanning = true;
      _fileList.clear();
      _fileCount = 0;
    });

    // 调用目录选择回调
    widget.onDirectorySelected?.call(directoryPath);

    // 扫描目录
    await _scanDirectory(directoryPath);

    setState(() {
      _isScanning = false;
      // 按文件名字母排序
      _fileList.sort((a, b) => a.path.compareTo(b.path));
      _fileCount = _fileList.length;
    });

    // 调用文件列表更新回调
    widget.onFileListUpdated?.call(_fileList);
  }

  @override
  void initState() {
    super.initState();

    // 处理初始目录
    if (widget.initialDirectory != null) {
      _selectedDirectory = widget.initialDirectory;
      if (widget.autoScanInitialDirectory) {
        _startScan(widget.initialDirectory!);
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

  // 递归扫描目录
  Future<void> _scanDirectory(String directoryPath) async {
    Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      print('目录不存在: $directoryPath');
      return;
    }

    try {
      // 使用异步方式获取目录实体，避免阻塞UI线程
      Stream<FileSystemEntity> entityStream = 
          directory.list(recursive: true, followLinks: false);

      await for (var entity in entityStream) {
        // 暂停10毫秒，避免UI卡顿
        await Future.delayed(const Duration(milliseconds: 10));
        
        try {
          if (entity is File) {
            // 检查文件是否可读
            if (entity.existsSync() && await entity.length() >= 0) {
              // 确保组件仍然处于挂载状态，避免setState() called after dispose()错误
              if (mounted) {
                setState(() {
                  _fileList.add(entity);
                });
              }
            }
          }
        } catch (fileError) {
          // 忽略单个文件的错误，继续扫描其他文件
          print('访问文件时出错: ${entity.path}, 错误: $fileError');
        }
      }
    } catch (e) {
      // 记录详细的目录扫描错误
      print('扫描目录时出错: $directoryPath, 错误: $e');
      
      // 在Android平台上，可能需要特殊处理分区存储限制
      if (Platform.isAndroid) {
        print('Android平台上的目录访问错误，可能是因为分区存储限制');
        // 尝试访问应用私有目录作为替代方案
        try {
          String? appDir = Directory.systemTemp.parent?.path;
          if (appDir != null) {
            print('尝试访问应用目录: $appDir');
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
          }
        } catch (appDirError) {
          print('访问应用目录时出错: $appDirError');
        }
      }
    }
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
                onPressed: _selectDirectory,
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

              Text(
                _isScanning
                    ? '正在扫描文件...'
                    : _fileCount > 0
                        ? '共找到 $_fileCount 个文件'
                        : '未找到文件',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),

        //separator
        const Divider(height: 1),

        // 文件列表
        Expanded(
          child: Stack(
            children: [
              _fileList.isEmpty
                  ? const Center(child: Text('请选择一个目录'))
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: _scrollController,
                        itemCount: _fileList.length,
                        // 使用separated更高效地添加分隔线
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          File file = _fileList[index];
                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file,
                                size: 20), // 添加文件图标
                            title: Text(
                              file.path,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
              // 底部信息栏
              if (_fileList.isNotEmpty) ...[
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
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
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 目录列表页面（为了向后兼容而保留）
class DirectoryListPage extends StatelessWidget {
  const DirectoryListPage({Key? key}) : super(key: key);

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
