import 'package:flutter/material.dart';
import '../lib/notification_service.dart';

class PersistentTestPage extends StatelessWidget {
  const PersistentTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('持久通知测试')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                notification.show(
                  title: '普通通知',
                  msg: '这个通知会在8秒后自动关闭',
                );
              },
              child: const Text('显示普通通知（对比）'),
            ),
            const SizedBox(height: 40),
            const Text(
              '测试说明：\n'
              '- 持久通知不会自动关闭\n'
              '- 普通通知8秒后自动关闭\n'
              '- 所有通知都可以手动关闭',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}