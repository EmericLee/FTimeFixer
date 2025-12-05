// ignore_for_file: avoid_print
// dart run release.dart [type]
// type: patch, minor, major, build
// build: 仅增加构建号，不改变版本号

import 'dart:io';

void main(List<String> args) {
  // 1. 获取参数，默认为 patch
  final type = args.isNotEmpty ? args[0] : 'patch';
  final allowedTypes = ['patch', 'minor', 'major', 'build'];

  if (!allowedTypes.contains(type)) {
    print('❌ 错误: 无效的升级类型 "$type". 可选值: ${allowedTypes.join(', ')}');
    exit(1);
  }

  print('🚀 开始发布流程 (类型: $type)...');

  // 2. 检查 Git 状态
  // runCommand 自定义函数在下面
  final status = runCommand('git', ['status', '--porcelain']);
  if (status.stdout.toString().trim().isNotEmpty) {
    print('🔄 Git 工作区不干净。 添加所有更改。');
    runCommand('git', ['add', '.']);
  }else{
    print('✅ Git 工作区干净，继续发布流程...');
  }

  try {
    // 3. 运行 Cider 升级版本
    // Windows下命令通常是 cider.bat 或通过 dart pub global run 调用
    // 为了最大化兼容性，我们直接调用 'cider' (前提是配置了环境变量)
    // 如果报错，可以尝试改成 ['pub', 'global', 'run', 'cider', 'bump', type, '--bump-build']
    print('🔄 正在升级版本号...');
    if (type == 'build') {
      runCommand('cider', ['bump', 'build']);
    } else {
      runCommand('cider', ['bump', type, '--bump-build']);
    }

    // 4. 获取新版本号
    final versionResult = runCommand('cider', ['version']);
    final newVersion = versionResult.stdout.toString().trim();
    print('✅ 版本已更新为: $newVersion');

    // 5. Git 提交与打 Tag
    print('📦 推送到远程仓库: git push && git push --tags');
    runCommand('git', ['add', '.']);

    final commitMsg = 'Release version v$newVersion';
    runCommand('git', ['commit', '-m', commitMsg]);

    final tagName = 'v$newVersion';
    runCommand('git', ['tag', '-a', tagName, '-m', 'Release v$tagName']);

    runCommand('git', ['push']);
    runCommand('git', ['push', '--tags']);
        print('🎉 发布完成！');
    print('👉 提交信息: $commitMsg  Tag: $tagName');

  } catch (e) {
    print('❌ 发生异常: $e');
    exit(1);
  }
}

// 辅助函数：运行 Shell 命令
ProcessResult runCommand(String command, List<String> args) {
  // 在 Windows 上，有些命令需要通过 shell 执行才能找到
  final result = Process.runSync(
    command, 
    args, 
    runInShell: true, // 关键：允许跨平台查找 PATH 中的命令
  );

  if (result.exitCode != 0) {
    print('❌ 执行命令失败: $command ${args.join(' ')}');
    print('错误输出: ${result.stderr}');
    throw Exception('Command failed');
  }
  return result;
}
