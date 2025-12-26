import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bot_toast/bot_toast.dart';
import 'directory_scan.dart';
import 'notification_service.dart';

// 首页组件
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 应用名称
              Text(
                'Flutter Demo',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 24),
              
              // 应用版本号
              _packageInfo != null
                  ? Text(
                      '版本: v${_packageInfo!.version} (${_packageInfo!.buildNumber})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    )
                  : const CircularProgressIndicator(),
              const SizedBox(height: 48),
              
              // 介绍文字
              const Text(
                '这是一个Flutter演示应用，展示了页面切换、文件扫描和状态保持等功能。\n\n' 
                '主要功能：\n' 
                '• 版本信息展示\n' 
                '• 文件系统扫描\n' 
                '• 状态保持的页面切换',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 文件扫描页组件
class FileScannerPage extends StatelessWidget {
  const FileScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件扫描'),
      ),
      body: const DirectoryListWidget(),
    );
  }
}

// 演示页组件
class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('演示'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('点按计数功能:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 64,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 115, 198, 7)),
      ),
      builder: BotToastInit(), // 配置BotToast
      navigatorObservers: [BotToastNavigatorObserver()], // 添加BotToast导航观察者
      home: Builder(
        builder: (context) {
          return const MyHomePage(title: 'Flutter Demo Home Page #');
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // 当前选中的页面索引
  int _currentIndex = 0;

  // 页面列表
  final List<Widget> _pages = const [
    HomePage(),
    FileScannerPage(),
    DemoPage(),
  ];

  // 导航栏项目列表
  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: '首页',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.folder_open),
      label: '文件扫描',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.play_arrow),
      label: '演示',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用IndexedStack保持页面状态
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8.0,
      ),
    );
  }
}
