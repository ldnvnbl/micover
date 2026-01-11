# macOS App Architecture

## 项目结构

```
macOS/
├── App/                           # 应用入口和配置
│   ├── macOSApp.swift            # 应用主入口
│   ├── AppDelegate.swift         # 应用代理
│   └── AppConstants.swift        # 应用常量配置
│
├── Views/                         # 视图层
│   ├── Root/
│   │   └── RootView.swift        # 根视图（路由控制）
│   │
│   ├── Dashboard/                # 主界面
│   │   ├── DashboardView.swift   # 仪表板主视图
│   │   ├── Components/           # 仪表板组件
│   │   │   ├── DashboardSidebar.swift        # 侧边栏导航
│   │   │   └── SmartPhraseEditSheet.swift    # 智能短语编辑弹窗
│   │   └── Pages/                # 仪表板页面
│   │       ├── HomePage.swift    # 首页
│   │       └── SmartPhrasesPage.swift # 智能短语页面
│   │
│   ├── LoginView.swift           # 登录视图
│   ├── PermissionRequestView.swift # 权限请求视图
│   │
│   ├── AudioView/
│   │   └── AudioView.swift       # 音频视图（调试用）
│   │
│   └── FloatingWindow/
│       └── FloatingWindowView.swift # 悬浮窗口
│
├── ViewModels/                    # 视图模型层
│   └── ContentViewModel.swift    # 内容管理视图模型
│
├── Models/                        # 数据模型
│   └── AppState.swift            # 应用状态管理
│
├── Services/                      # 服务层
│   ├── PermissionManager.swift   # 权限管理（麦克风、辅助功能）
│   ├── RecordingCoordinator.swift # 录音流程协调器
│   ├── HotkeyManager.swift       # 全局快捷键管理
│   ├── PushToTalkService.swift   # Push-to-Talk 服务
│   └── TextInputService.swift    # 文本输入服务
│
└── Resources/                     # 资源文件
    ├── Assets.xcassets           # 图片资源
    └── macOS.entitlements        # 应用权限配置
```

## 架构设计原则

### 分层架构
- **View 层**: SwiftUI 视图，负责 UI 展示
- **ViewModel 层**: 业务逻辑和状态管理
- **Service 层**: 系统功能封装和外部服务交互
- **Model 层**: 数据模型和应用状态

### 核心服务
- **Shared 模块服务**（跨平台）:
  - `WebSocketService`: WebSocket 通信
  - `AudioService`: 音频录制
  - `AuthenticationService`: 认证服务
  - `SmartPhrasesService`: 智能短语管理

- **macOS 特定服务**:
  - `PermissionManager`: 系统权限管理
  - `PushToTalkService`: Fn 键录音服务
  - `HotkeyManager`: 全局快捷键监听
  - `TextInputService`: 自动文本粘贴

### 依赖注入
- 使用 SwiftUI 的 `@Environment` 注入共享服务
- 使用 `@StateObject` 和 `@ObservedObject` 管理视图模型

## 核心流程

### 应用启动流程
1. **RootView** 检查权限状态
2. 无权限 → **PermissionRequestView**
3. 未登录 → **LoginView**
4. 已登录 → **DashboardView**

### Push-to-Talk 流程
1. 用户按下 Fn 键
2. `HotkeyManager` 捕获事件
3. `PushToTalkService` 开始录音
4. 通过 WebSocket 发送音频数据
5. 接收转写结果
6. `TextInputService` 自动粘贴文本

### 智能短语管理
1. **SmartPhrasesPage** 展示短语列表
2. **SmartPhraseEditSheet** 提供编辑界面
3. `SmartPhrasesService` 处理 API 交互
4. 支持创建、编辑、删除操作

## UI 设计规范

### 布局原则
- 内容最大宽度: 800px
- 统一的容器模式
- 响应式设计，适配不同屏幕

### 组件规范
- 侧边栏宽度: 240px
- 统一的卡片样式
- 一致的间距和内边距

## 技术栈

- **SwiftUI**: UI 框架
- **Swift Concurrency**: 异步编程
- **Alamofire**: 网络请求
- **KeychainAccess**: 安全存储
- **AVFoundation**: 音频处理
- **WebSocket**: 实时通信

## 后续优化

1. **性能优化**
   - 减少不必要的视图重绘
   - 优化 WebSocket 连接管理

2. **功能增强**
   - 添加更多快捷键支持
   - 增强智能短语功能
   - 支持语音识别配置

3. **用户体验**
   - 添加更多动画效果
   - 优化错误提示
   - 增强无障碍支持