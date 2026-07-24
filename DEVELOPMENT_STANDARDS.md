<!--
  DEVELOPMENT_STANDARDS.md
  Author: Maru
-->

# Xdnmb 开发规范

本文档是项目持久化开发规范。所有代码、架构、功能和文档变更均需遵守。

## 1. 文件与命名

- 新文件首行必须包含文件头，作者统一为 `Maru`。
- 类型名表达领域职责：页面用 `Screen`，可观察业务状态用 `Store`，远程抽象用 `Client`，纯视觉单元用 `View` 或语义组件名。
- 一个文件只承载一个紧密相关的功能或组件族；跨功能复用代码进入 `Module` 或 `UI`。
- 禁止重新引入未使用的 legacy 目录、UIKit 页面层或重复状态模型。

Swift 文件头：

```swift
//
// Filename.swift
// Author: Maru
//
```

## 2. 依赖规则

- `XdnmbAppView` 是唯一 composition root。
- Feature 和 Module 只依赖 `XdnmbAPIClient`，禁止直接调用 `APIService.shared`。
- View 不创建网络服务，不拼接 API 请求身份，不实现分页规则。
- Data 不依赖 Feature 或 UI；可复用 Module 不依赖具体页面。
- 新依赖必须通过初始化参数或 SwiftUI Environment 注入，并提供可测试替代实现。

## 3. 状态所有权

- App 全局状态：由 `AppModel`、`IdentityStore`、`BoardPreferencesStore` 持有。
- 导航往返需要保留的业务状态：由 `AppSessionStore` 管理的 Store 持有。
- 页面临时展示状态（sheet、alert、输入焦点）：使用页面 `@State`。
- View 不得使用额外布尔标记模拟 Store 是否已加载；加载身份与幂等性属于 Store。
- Published 属性原则上 `private(set)`；外部通过明确 action 修改。

## 4. SwiftUI 生命周期

- 页面 `.task(id:)` 可以重复执行，因此调用的 `activate` 必须幂等。
- 进入子页面再返回不得隐式执行 refresh、reset 或 jump。
- Feed 类列表依赖 `NavigationStack` 原生 push/pop 保留滚动位置；禁止把连续变化的可见项绑定到业务 Store 来强制恢复位置。
- 只有显式用户操作可以清空、替换列表或滚动到顶部。
- NavigationLink 优先使用直接 destination closure；只有确有统一路由需求时才使用 value/destination 注册，并保证声明位于可见的 NavigationStack 范围。
- Tab 子页的导航栏尺寸必须稳定，按钮使用固定布局，不根据标题字符数反复改变宽度。

## 5. 异步与分页

- 所有可取消请求检查 `Task.isCancelled` 或 `Task.checkCancellation()`，取消不展示为错误。
- Store 用请求 token 防止旧请求覆盖新身份或新来源。
- 初始加载、刷新、加载更多和跳页必须是四个独立 action。
- 加载更多必须防重入；空结果、无新增结果、达到最大页或错误后停止自动触发。
- 刷新已有内容时保留当前数据，成功后再替换，避免闪屏。
- 错误必须提供明确的人工重试入口，不能依靠 View 重现自动重试。

## 6. API 与安全

- API 行为、参数、认证和模型变化首先同步 `xdnmb_api.md`。
- userhash 只从 `IdentityStore` 获取；日志、错误和测试输出不得打印完整凭据。
- Feed ID 和 userhash 在发送前继续执行格式校验。
- Keychain 是饼干的唯一持久化位置；不得降级保存到明文 UserDefaults。
- 相机、照片和网络权限遵循最小授权，不扩展当前数据采集范围。

## 7. 测试

业务 Store 必须通过假的 `XdnmbAPIClient` 测试，不使用线上 API 证明状态行为。

列表状态机测试命令：

```sh
xcrun swiftc -module-cache-path /tmp/Xdnmb-Swift-ModuleCache -parse-as-library \
  Xdnmb/Source/Utils/DecodingUtilities.swift \
  Xdnmb/Source/Utils/ContentUtilities.swift \
  Xdnmb/Source/Model/Forum.swift \
  Xdnmb/Source/Model/Thread.swift \
  Xdnmb/Source/Data/XdnmbAPIClient.swift \
  Xdnmb/Source/Data/PostHistoryStore.swift \
  Xdnmb/Source/Application/PreviewSupport.swift \
  Xdnmb/Source/Module/Pagination/ThreadListStore.swift \
  Xdnmb/Source/Module/Thread/ThreadStore.swift \
  Xdnmb/Source/Module/Composer/ComposerStore.swift \
  Tests/ThreadListStoreStateTests.swift \
  -o /tmp/ThreadListStoreStateTests
/tmp/ThreadListStoreStateTests
```

构建必须覆盖 Debug 模拟器和 Release 真机配置，并设置：

```text
CODE_SIGNING_ALLOWED=NO
SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

## 8. 文档同步

下列任一变化必须在同一提交更新根目录 `CODE_ARCHITECTURE.md`：

- 新增、删除、移动模块或改变依赖方向。
- 改变 Store 的状态所有权、生命周期或缓存策略。
- 新增、删除或改变用户功能、导航入口和 API 能力。
- 改变通用组件契约、分页规则、身份规则或持久化策略。

开发规范自身变化同步本文档。API 变化同步 `xdnmb_api.md`。文档未同步视为功能未完成。

## 9. Git 与交付

- 不提交 DerivedData、build 产物、用户 Xcode 状态、签名私钥、Provisioning Profile、`.DS_Store` 或本地密钥。
- 提交前检查 `git status`，不覆盖与当前任务无关的用户改动。
- 必须执行 `git diff --check`。
- 不用通过隐藏警告、关闭检查或删除失败测试来获得绿色构建。

## 10. Definition of Done

功能只有同时满足以下条件才算完成：

1. 代码符合架构依赖和状态所有权规则。
2. 用户功能和无障碍语义未发生非预期退化。
3. 相关状态测试通过。
4. Debug 与 Release 构建无警告、无错误。
5. API、架构和开发规范文档已按变更同步。
6. 工作区无格式错误或意外生成物。
