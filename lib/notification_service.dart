import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bot_toast/bot_toast.dart';

/// 通知服务类，提供统一的信息提示接口

class NotificationService {
  // 单例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 维护当前的消息列表
  final ValueNotifier<List<_ToastItem>> _itemsNotifier = ValueNotifier([]);
  CancelFunc? _cancelFunc;

  /// 初始化通知栈（建议在 App 启动或首页加载时调用一次）
  void init() {
    if (_cancelFunc != null) return; // 避免重复初始化

    _cancelFunc = BotToast.showWidget(
      groupKey: 'notification_stack',
      toastBuilder: (_) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight, // 1. 设定位置：右上角
            child: Container(
              margin: const EdgeInsets.only(top: 10, right: 10),
              width: 320, // 2. 设定通知的宽度
              child: ValueListenableBuilder<List<_ToastItem>>(
                valueListenable: _itemsNotifier,
                builder: (context, items, _) {
                  // 3. 使用 Column 实现垂直排列
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      return _ToastWidget(
                        key: ValueKey(item.id),
                        item: item,
                        onDismiss: () => _remove(item.id),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 发送通知
  void show({String title = '', required String msg, Duration? duration, bool persistent = false}) {
    // 如果还没初始化，自动初始化
    if (_cancelFunc == null) init();

    // 使用微秒数+随机数确保ID唯一
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1000);
    final id = '$timestamp$random';
    
    final item = _ToastItem(
      id: id,
      title: title,
      msg: msg,
      duration: persistent ? null : (duration ?? const Duration(seconds: 4)),
      persistent: persistent,
    );

    // 添加到列表，触发 UI 更新
    final List<_ToastItem> currentList = List.from(_itemsNotifier.value);
    currentList.add(item); // 新消息加在底部（或者用 insert(0, item) 加在顶部）
    _itemsNotifier.value = currentList;
  }

  void _remove(String id) {
    final List<_ToastItem> currentList = List.from(_itemsNotifier.value);
    currentList.removeWhere((e) => e.id == id);
    _itemsNotifier.value = currentList;
  }
}

// 数据模型
class _ToastItem {
  final String id;
  final String title;
  final String msg;
  final Duration? duration;
  final bool persistent;
  _ToastItem({required this.id, required this.title, required this.msg, this.duration, required this.persistent});
}

// 单个通知组件（带动画）
class _ToastWidget extends StatefulWidget {
  final _ToastItem item;
  final VoidCallback onDismiss;

  const _ToastWidget({Key? key, required this.item, required this.onDismiss}) : super(key: key);

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _offset = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 播放入场动画
    _controller.forward();

    // 启动倒计时自动关闭（仅当非持久模式时）
    if (!widget.item.persistent && widget.item.duration != null) {
      _timer = Timer(widget.item.duration!, () => _close());
    }
  }

  void _close() async {
    _timer?.cancel();
    await _controller.reverse(); // 播放退场动画
    widget.onDismiss(); // 从列表中移除
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 使用 SizeTransition 或 ClipRect 可以在移除时让下方元素平滑上移
        return FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: child,
          ),
        );
      },
      child: Card(
        color: Colors.white,
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 10), // 消息之间的间距
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.item.msg, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: _close,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
        ),
      ),
    );
  }
}


/// 全局通知服务实例，方便直接使用
final notification = NotificationService();
