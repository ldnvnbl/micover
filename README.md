# MicOver

![macOS](https://img.shields.io/badge/macOS-14.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.1-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)
![Release](https://img.shields.io/github/v/release/ldnvnbl/micover)

**MicOver** 是一款 macOS 语音输入工具，采用 Push-to-Talk 模式，让您可以在任何应用中快速进行语音输入。按住快捷键说话，松开即自动将识别结果输入到当前光标位置。

---

## ✨ 功能特性

### 核心功能
- **Push-to-Talk 语音输入** - 按住快捷键说话，松开即自动输入文字
- **全局快捷键** - 支持 Fn 键和自定义组合键，在任何应用中都可使用
- **实时语音识别** - 基于 WebSocket 的流式语音识别，响应迅速
- **自动粘贴** - 识别结果自动粘贴到当前光标位置

### 智能功能
- **智能短语** - 设置触发词自动执行操作（打开应用、输入预设文本）
- **Over 命令** - 说 "over" 结尾自动发送回车键
- **历史记录** - 查看所有语音输入历史和统计数据

### 界面功能
- **悬浮窗口** - 实时显示录音状态和识别结果
- **今日统计** - 录音次数、使用时长、转写字数等数据统计
- **深色模式** - 完美支持 macOS 深色模式

---

## 📥 安装

### 下载安装（推荐）

1. 前往 [Releases](https://github.com/ldnvnbl/micover/releases) 页面
2. 下载最新版本的 `MicOver_x.x.dmg`
3. 打开 DMG 文件，将 MicOver 拖入 Applications 文件夹
4. 首次启动时，按提示授权麦克风和辅助功能权限

### 从源码构建

#### 系统要求
- macOS 14.0 (Sonoma) 或更高版本
- Xcode 16.0 或更高版本
- Swift 6.1

#### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/ldnvnbl/micover.git
cd micover

# 构建 Debug 版本
xcodebuild -workspace MicOver.xcworkspace -scheme macOS -configuration Debug build

# 或使用快捷脚本构建并运行
./run.sh
```

---

## 🔧 配置

### 权限设置

首次启动 MicOver 时，需要授权以下权限：

| 权限 | 用途 |
|------|------|
| **麦克风** | 录制语音进行识别 |
| **辅助功能** | 全局快捷键监听和自动粘贴文字 |

### 🔑 API Key 配置

> **重要**：MicOver 使用 [火山引擎](https://www.volcengine.com/) 的语音识别服务，您需要自行申请 API Key 才能使用语音识别功能。

#### 获取 API Key

1. 访问 [火山引擎控制台](https://console.volcengine.com/)
2. 注册或登录您的账号
3. 开通「语音技术」-「语音识别」服务
4. 创建应用并获取 **App ID** 和 **Access Token**

> 详细教程请参考 [火山引擎语音识别文档](https://www.volcengine.com/docs/6561/80816)

#### 配置到 MicOver

1. 打开 MicOver
2. 进入「设置」页面
3. 在「API 配置」区域填入您的 API Key
4. 保存后即可使用语音输入功能

---

## 🚀 使用方法

### 基本使用

1. 启动 MicOver，确保状态显示「已就绪」
2. 将光标放在任意文本输入位置
3. **按住** Fn 键（或您设置的快捷键）
4. 开始说话
5. **松开** 快捷键，识别结果将自动输入

### 快捷键设置

- 默认快捷键为 **Fn** 键
- 可在「设置」→「快捷键」中修改为其他组合键（如 Option + Q）

### 智能短语

设置触发词实现快速操作：

| 触发词示例 | 操作 |
|-----------|------|
| "打开浏览器" | 启动 Safari |
| "我的邮箱" | 输入预设的邮箱地址 |

### Over 命令

在语音结尾说 "over"，MicOver 会自动：
1. 去掉 "over" 文字
2. 发送回车键

适合在聊天应用中快速发送消息。

---

## 🛠️ 开发

### 项目结构

```
MicOver/
├── Shared/                    # 跨平台 SPM 库
│   └── Sources/Shared/
│       ├── Audio/             # 音频录制和转换
│       ├── Core/Storage/      # Keychain 和存储
│       └── SpeechRecognition/ # 语音识别服务
├── macOS/macOS/               # macOS 应用
│   ├── App/                   # 应用入口
│   ├── Services/              # 核心服务
│   ├── Views/                 # SwiftUI 视图
│   └── ViewModels/            # 视图模型
└── MicOver.xcworkspace        # Xcode 工作区
```

### 依赖项

| 库 | 版本 | 用途 |
|---|------|------|
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | 4.2.2 | 安全存储 API Key |
| [HotKey](https://github.com/soffes/HotKey) | 0.2.1 | 全局快捷键监听 |
| [Alamofire](https://github.com/Alamofire/Alamofire) | 5.10.2 | HTTP 网络请求 |

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

---

## 🙏 致谢

- [火山引擎](https://www.volcengine.com/) - 语音识别服务
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain 封装库
- [HotKey](https://github.com/soffes/HotKey) - 全局快捷键库

---

## 📮 反馈

如有问题或建议，欢迎 [提交 Issue](https://github.com/ldnvnbl/micover/issues)。
