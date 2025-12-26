# Initlize Flutter Project - SDK & Tools
# ------------------------------------------

# Install Flutter SDK & Tools
# ------------------------------------------
# Download Flutter SDK from https://flutter.dev/docs/get-started/install

# Extract Flutter SDK to E:\SDK\FlutterSDK\flutter

# Add Flutter SDK to PATH , set temporary && set permanently
$env:Path += ";E:\SDK\FlutterSDK\flutter\bin";[Environment]::SetEnvironmentVariable("Path", $env:Path, "User") 

# install required tools
dart pub global activate cider
cider version

# Verify Flutter Installation & Tools
flutter doctor
flutter clean
flutter pub get
flutter run -d windows
flutter build windows


# 
# Initlize Flutter for windows platform #
#
# 1.Install Visual Studio Build Tools
# Visual Studio Build Tools 是Flutter Windows平台构建所必需的开发工具包，包含了C++编译器、CMake等关键组件。
# 下载安装程序
#    - 访问 Visual Studio下载页面 https://visualstudio.microsoft.com/zh-hans/downloads/
#    - 选择"Visual Studio Build Tools 2019"或"Visual Studio Build Tools 2022"（推荐2019版本与Flutter兼容性更好）
# 运行安装程序
#    - 双击下载的 vs_buildtools.exe 文件开始安装
#    - 在安装界面中，选择"使用C++的桌面开发" workload

# 2. Install NuGet for windows framework
# ------------------------------------------
New-Item -ItemType Directory -Path "E:\SDK\NuGet" -Force
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "E:\SDK\NuGet\nuget.exe"
$env:Path += ";E:\SDK\NuGet "
[Environment]::SetEnvironmentVariable("Path", $env:Path, "User")

#set NuGet Config
New-Item -ItemType Directory -Path "$env:APPDATA\NuGet" -Force
Set-Content -Path "$env:APPDATA\NuGet\NuGet.Config" -Encoding UTF8 -Value @(
    "<?xml version='1.0' encoding='utf-8'?>",
    "<configuration>",
    "  <packageSources>",
    "    <add key='nuget.org' value='https://api.nuget.org/v3/index.json' protocolVersion='3' />",
    "  </packageSources>",
    "</configuration>"
)

#
# Initlize Flutter for android platform #
# 
# 1. Install Android Studio
# Android Studio 是Flutter Android平台开发的主要集成开发环境（IDE），提供了丰富的工具和插件。
# 下载安装程序
#    - 访问 Android Studio 下载页面 https://developer.android.com/studio
#    - 选择"Download Android Studio"，根据操作系统下载对应的安装程序
# 运行安装程序
#    - 双击下载的 android-studio-*.exe 文件开始安装
#    - 按照安装向导的指示完成安装
#    - 启动 Android Studio，按照向导配置SDK路径、插件等
# 2. 安装Flutter插件
#    - 在 Android Studio 中，打开"Preferences"（或"Settings"）
#    - 导航到"Plugins"部分
#    - 搜索并安装"Flutter"插件
#    - 安装完成后，重启 Android Studio 以启用 Flutter 插件
# 3. 配置模拟器
#    - 打开 Android Studio，导航到"AVD Manager"（Android Virtual Device Manager）
#    - 启动模拟器，确保它正常运行
flutter devices
emulator -list-avds