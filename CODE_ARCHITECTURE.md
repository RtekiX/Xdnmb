<!--
  CODE_ARCHITECTURE.md
  Author: Maru
-->

# Xdnmb 代码架构

本文档描述 Xdnmb iOS 客户端的当前代码架构，是功能边界、状态所有权和依赖方向的权威说明。API 能力以同目录下的 [`xdnmb_api.md`](./xdnmb_api.md) 为准。

最后同步：2026-07-22

## 架构目标

- 高内聚：网络、会话状态、页面渲染和本地持久化分别由明确模块负责。
- 低耦合：功能层依赖 `XdnmbAPIClient`，不依赖具体网络实现或全局单例。
- 单向数据流：View 发送用户意图，Store 执行业务流程并发布只读状态，View 根据状态渲染。
- 稳定生命周期：列表和串详情状态由应用会话层持有，不由可能重建的 `TabView` 或导航子页临时拥有。
- 易测试：API 通过协议替换，分页与页面生命周期可以在不访问网络的情况下验证。
- 文档同步：架构、模块、状态流或用户功能发生变化时，必须在同一改动中更新本文档。

## 目录与职责

```text
Xdnmb/Source/
├── Architecture/   依赖注入、应用会话和模块装配
├── Application/    App 根视图、全局站点状态、Preview 运行环境
├── Data/           API 实现、本地身份与版块偏好持久化
├── Model/          API 领域模型
├── Module/         可复用业务状态机
│   ├── Composer/   发串与回复提交工作流
│   ├── Pagination/ 时间线、版块、订阅共用分页会话
│   └── Thread/     串详情会话
├── Features/       按用户功能组织的 SwiftUI 页面与交互
├── UI/             无业务归属的视觉组件和列表容器
└── Utils/          纯函数、解码和集合工具
```

依赖方向必须保持为：

```text
Application → Architecture → Module → Data(protocol) / Model
Features    → Architecture / Module / UI / Model
Data        → Model / Utils
UI          → Model（仅展示所需）
```

`Data` 中的 `APIService` 是 `XdnmbAPIClient` 的线上实现。Features 和 Module 不允许直接读取 `APIService.shared`。

## 应用装配与依赖注入

`XdnmbAppView` 是 composition root，负责创建并注入：

| 对象 | 生命周期 | 职责 |
|---|---|---|
| `AppModel` | App | 站点 bootstrap、版块/时间线/公告、订阅集合、串阅读位置 |
| `IdentityStore` | App | Keychain 中的饼干、浏览/发帖主饼干、Feed ID |
| `BoardPreferencesStore` | App | 版块显示、隐藏与排序偏好 |
| `AppSessionStore` | App | 列表与串详情 Store 的稳定所有权和缓存 |
| `XdnmbAPIClient` | App | 所有远程 API 的抽象依赖 |

SwiftUI 页面通过 Environment 获得应用状态和会话 Store；API 依赖只在 composition root 通过初始化参数传入 `AppModel` 与 `AppSessionStore`。Preview 使用相同页面结构和本地 fixtures，不发出线上请求。

## 会话状态模型

### 列表会话

`ThreadListStore` 是时间线、版块和订阅的唯一分页状态机。三类来源由 `ThreadListSource` 表达：

- `.timeline(id:maximumPage:)`
- `.forum(id:maximumPage:)`
- `.feed(id:)`

Store 统一拥有帖子、当前页、初始加载状态、加载更多状态、错误和是否还有下一页。核心不变量：

1. `activate(source:userHash:)` 是幂等操作。同一来源和同一浏览身份已成功激活后，再次调用不会请求网络。
2. 导航进入串再返回时，SwiftUI 可以重新执行页面 `.task`，但幂等激活不会改变任何 Published 状态，也不会刷新或重排列表。
3. 下拉刷新只由 `refresh()` 触发；跳页只由 `jump(to:)` 触发；触底加载只由 `loadMore()` 触发。
4. 请求取消时不提交半完成结果；若首次加载被取消且尚无有效结果，下次激活会恢复加载。
5. 空页、重复页或失败页会停止自动翻页，避免触底触发器形成请求循环。
6. 刷新和跳页期间保留已有内容，成功后再原子替换，避免页面闪烁。

`AppSessionStore` 持有一个时间线会话、一个订阅会话以及按版块 ID 缓存的版块会话。因此页面视图重建不会丢失分页结果。

### 串详情会话

`ThreadStore` 负责串详情、当前页、只看 PO、加载状态和错误。`AppSessionStore` 按串号缓存最近 32 个 Store；更早的会话可回收，阅读页码和帖子锚点仍由 `AppModel` 保存。

串详情的 `activate(userHash:)` 同样幂等，导航层不负责决定是否刷新。回复成功、切换只看 PO、上一页/下一页属于明确用户意图，会调用对应 Store action。

### 提交会话

`ComposerStore` 负责发串/回复请求、发送中状态与远程错误；`ComposerScreen` 只持有尚未提交的表单草稿、附件选择和输入焦点。目标由 `ComposerDestination` 表达，草稿由 `ComposerDraft` 传入，页面不直接调用 API。

### 滚动位置

Feed 类列表不把“当前可见项”持续写回业务状态。正常 push/pop 使用 `NavigationStack` 和 `ScrollView` 的原生生命周期保留位置，从而避免滚动绑定、LazyVStack 布局和触底加载互相反馈。

显式跳页通过 `scrollToTopRequest` 请求列表滚到顶部。串详情因需要跨会话恢复阅读进度，单独使用 `ThreadReadingPosition` 保存页码与帖子 ID。

## 功能模块

| 功能 | 页面入口 | 状态/服务 | API 能力 |
|---|---|---|---|
| 综合时间线 | `TimelineScreen` | `ThreadListStore.timeline` | 时间线列表、时间线帖子、站点公告 |
| 版块浏览 | `ForumScreen`、`BoardDirectoryScreen` | `ThreadListStore.forum`、版块偏好 | 版块列表、版块帖子 |
| 订阅 Feed | `FeedScreen` | `ThreadListStore.feed`、`AppModel.subscribedThreadIDs` | Feed 列表、添加/删除订阅 |
| 串详情 | `ThreadDetailScreen` | `ThreadStore`、阅读位置 | 完整串、只看 PO、分页 |
| 发串与回复 | `ComposerScreen` | `ComposerStore`、页面草稿状态 | 发新串、回复、图片上传 |
| 身份与个人页 | `ProfileScreen` | `IdentityStore` | 饼干导入/选择、最近发帖、Feed ID |
| 版块定制 | `BoardManagementScreen` | `BoardPreferencesStore` | 本地显示、隐藏、拖动排序 |
| 协议与政策 | `ProfileScreen` → No.11689471 | `ThreadStore` | 读取指定串 |

## UI 组件边界

- `RefreshableInfiniteList`：只负责列表布局、下拉刷新、触底信号、导航栏显隐和显式滚顶；不拥有分页规则和数据身份。
- `MainFeedChromeModel`：在分页 Tab 容器与当前子页之间传递固定宽度的导航栏展示状态及用户操作。
- `ThreadCard` / `PostCard` / 公告卡片：纯展示组件，不发起 API 请求。
- `PageJumpSheet`：只验证并回传页码，不改变 Store。

## API 扩展流程

新增或修改 API 时必须同时完成：

1. 更新 `xdnmb_api.md` 的接口与数据结构。
2. 在 `XdnmbAPIClient` 添加抽象能力。
3. 在 `APIService` 实现线上请求、校验和错误映射。
4. 将 API 调用放入对应 Store 或专用服务，View 只发送 action。
5. 为请求身份、分页、取消或错误状态补充可替换 API 的测试。
6. 更新本文档的功能矩阵、状态流或目录说明。

## 测试与验证

`Tests/ThreadListStoreStateTests.swift` 使用假的 `XdnmbAPIClient` 验证列表、串详情和提交 Store，包括导航返回不刷新、分页追加、空页停止、错误停止与人工重试、主动刷新、身份切换、串分页、订阅结果以及发串/回复目标。

提交前至少执行：

- 状态机测试。
- Debug 模拟器构建，开启 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`。
- Release 真机构建，关闭签名并开启 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`。
- `git diff --check` 和架构约束搜索。

具体命令和代码规则见 [`DEVELOPMENT_STANDARDS.md`](./DEVELOPMENT_STANDARDS.md)。

## 架构变更记录

| 日期 | 变更 |
|---|---|
| 2026-07-22 | 建立 `XdnmbAPIClient` 依赖边界与 App composition root；引入 `AppSessionStore`、统一 `ThreadListStore`、`ThreadStore` 与 `ComposerStore`；时间线、版块、订阅、串详情、订阅操作及发帖工作流迁移到 Store；列表返回依赖原生导航滚动保留；新增状态生命周期测试。 |
