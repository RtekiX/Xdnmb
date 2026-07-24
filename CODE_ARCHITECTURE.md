<!--
  CODE_ARCHITECTURE.md
  Author: Maru
-->

# Xdnmb 代码架构

本文档描述 Xdnmb iOS 客户端的当前代码架构，是功能边界、状态所有权和依赖方向的权威说明。API 能力以同目录下的 [`xdnmb_api.md`](./xdnmb_api.md) 为准。

最后同步：2026-07-24

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
| `BoardPreferencesStore` | App | 首页常驻版块的显示、隐藏与排序偏好 |
| `PostHistoryStore` | App | 本机成功发布的主题与回复、JSON 持久化、删除与清空 |
| `AppSessionStore` | App | 列表与串详情 Store 的稳定所有权和缓存 |
| `AppBottomAccessoryModel` | App | 系统 Tab Bar accessory 的展示身份、文案和回复动作 |
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

`ComposerStore` 负责发串/回复请求、发送中状态、远程错误和成功目标；发新主题成功后使用同一发帖饼干查询最近发送记录，以补齐可导航的主楼 ID。`ComposerScreen` 只持有尚未提交的表单草稿、附件选择和输入焦点，并将成功结果写入 `PostHistoryStore`。本机历史保存标题、正文、署名、时间、目标和附件标记，不保存图片数据、userhash 或其他凭据。

### 滚动位置

Feed 类列表不把“当前可见项”持续写回业务状态。正常 push/pop 使用 `NavigationStack` 和 `ScrollView` 的原生生命周期保留位置，从而避免滚动绑定、LazyVStack 布局和触底加载互相反馈。

显式跳页通过 `scrollToTopRequest` 请求列表滚到顶部。串详情因需要跨会话恢复阅读进度，单独使用 `ThreadReadingPosition` 保存页码与帖子 ID。

`RefreshableInfiniteList` 通过 `onScrollGeometryChange` 输出归一化纵向偏移，并通过 `onScrollPhaseChange` 输出手势/减速阶段，但不持久化偏移，也不改变 Store。首页的 `HomeNavigationState` 将相邻偏移差按 56pt 行程连续映射为 `0...1` 的来源轨道显示进度，因此轨道位移与手指逐帧同步；滚动停止后才吸附到完全展开或完全收起，避免半截状态。回到顶部、切换来源或开启 VoiceOver 时强制恢复；系统 Tab Bar 在 iOS 26 使用 `tabBarMinimizeBehavior(.onScrollDown)` 独立响应滚动。

## 功能模块

| 功能 | 页面入口 | 状态/服务 | API 能力 |
|---|---|---|---|
| 首页来源 Feed | `MainFeedScreen` → `TimelineScreen` / `ForumScreen` | `ThreadListStore.timeline`、按版块缓存的 `ThreadListStore.forum` | 时间线、版块帖子、公告、串号直达、发新串 |
| 订阅 Feed | `FeedScreen` | `ThreadListStore.feed`、`AppModel.subscribedThreadIDs` | Feed 列表、添加/删除订阅 |
| 串详情 | `ThreadDetailScreen` | `ThreadStore`、阅读位置 | 完整串、只看 PO、分页 |
| 发串与回复 | `ComposerScreen` | `ComposerStore`、页面草稿状态 | 发新串、回复、图片上传 |
| 发布历史 | `PostHistoryScreen` | `PostHistoryStore` | 本机主题/回复时间流、类型筛选、删除、清空、跳转对应串 |
| 身份与个人页 | `ProfileScreen` | `IdentityStore` | 饼干导入/选择、最近发帖、Feed ID |
| 常驻版块定制 | `MainFeedScreen` sheet → `BoardManagementScreen` | `BoardPreferencesStore` | 本地搜索、添加、移除、无限量常驻与拖动排序 |
| 协议与政策 | `ProfileScreen` → No.11689471 | `ThreadStore` | 读取指定串 |

## 顶层导航与 UI 组件边界

顶层使用系统 `TabView` 承载“首页 / 订阅 / 历史 / 我的”四个 Tab，每项内部持有独立 `NavigationStack`。系统同时负责选择状态、底部视觉、动态宽度、安全区和无障碍语义：

- 首页不再叠加系统 Navigation Title。固定 48pt 的 `HomeSourceBar` 同时容纳来源选择、低频操作菜单与当前来源的唯一主操作，形成单层玻璃指令轨道。
- 指令轨道固定“综合线”并横向展示用户的全部常驻版块；常驻数量不设上限，超出宽度后左右滚动。轨道不参与 Feed 高度布局，Feed 使用 48pt 可滚动顶部 content margin，与列表自身顶部 padding 配合后紧贴 48pt 轨道；滚动时轨道只改变位移与透明度，避免安全区重排、闪白和裁切。
- 首页使用全屏绘制容器让 Feed 延伸到状态栏下方；顶部使用不含不透明色板的渐隐 `regularMaterial`，滚动内容可在其下方产生真实模糊。来源轨道按运行时安全区 inset 放置，并使用可交互 Liquid Glass 与轻微高光描边，既不留下状态栏白底，也不会侵入状态栏。
- 轨道收起后显示不占内容布局的紧凑来源胶囊与主操作，保留当前位置、菜单和手动恢复入口；VoiceOver 启用时强制保持完整轨道。
- 点击来源胶囊或左右轻扫会在同一首页中切换 `TimelineScreen` / `ForumScreen`。分页 Store 仍由 `AppSessionStore` 按来源缓存，因此切换后保留内容、页码与会话状态。
- `HomeFeedChromeModel` 将当前可见来源的公告、页码、串号直达或发串动作映射到首页指令轨道；非当前页不得覆盖指令状态。
- 指令菜单打开 `BoardManagementScreen` 大尺寸 sheet。用户可以搜索待添加版块、显式添加或移除，并通过拖动调整常驻顺序；综合线不参与排序且固定在首位。
- `BoardPreferencesStore` 只在全新偏好上初始化前四个常驻版块；已存在的选择不会在迁移时裁剪，用户之后可添加任意数量。
- iOS 26 使用系统 Liquid Glass Tab Bar 与 `tabViewBottomAccessory`，隐藏 Tab Bar 的整宽自动背景并由全屏 grouped background 承接安全区，只保留系统浮动玻璃控件；未显示 accessory 时不挂载空容器，避免底部出现额外白边或空胶囊。iOS 18–25 使用系统 Tab Bar 的 `ultraThinMaterial` 背景，回复动作以不改变安全区的透明 overlay 胶囊降级。
- 串详情通过 App 级 `AppBottomAccessoryModel` 注册回复动作；切换页签或离开详情时按 owner 清理。根页面不再通过自定义 `safeAreaInset` 包裹底部内容，底部空间由系统 Tab Bar 管理。
- 订阅页的页码跳转进入 Inline Title 菜单；“我的”使用可由系统自然折叠的 Large Title。
- `ThreadCard` 与 `PostCard` 使用无头像的紧凑元数据行；PO、管理身份、时间和串号仍保留，低频“更多”不作为外露按钮。

- `RefreshableInfiniteList`：只负责紧凑列表布局、可滚动顶部 margin、下拉刷新、触底信号、显式滚顶、滚动偏移和滚动阶段事件；不拥有分页规则、导航呈现或数据身份。
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

`Tests/ThreadListStoreStateTests.swift` 使用假的 `XdnmbAPIClient` 验证列表、串详情和提交 Store，包括导航返回不刷新、分页追加、空页停止、错误停止与人工重试、主动刷新、身份切换、串分页、订阅结果、发串/回复成功目标以及发布历史的写入、重载和删除持久化。`Tests/BoardPreferencesStoreStateTests.swift` 验证默认常驻、无限量添加、拖动顺序持久化与既有偏好迁移。`Tests/HomeNavigationStateTests.swift` 验证导航迟滞阈值、来源切换基线、回顶恢复、无障碍保护和底部 accessory 所有权。

提交前至少执行：

- 状态机测试。
- Debug 模拟器构建，开启 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`。
- Release 真机构建，关闭签名并开启 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`。
- `git diff --check` 和架构约束搜索。

具体命令和代码规则见 [`DEVELOPMENT_STANDARDS.md`](./DEVELOPMENT_STANDARDS.md)。

## 架构变更记录

| 日期 | 变更 |
|---|---|
| 2026-07-24 | 顶部管理栏改为可交互 Liquid Glass，并移除渐隐材质下方的 grouped background 不透明色层；Feed 滚动到状态栏和来源轨道下方时由 `regularMaterial` 实时模糊，旧系统使用同级材质降级。 |
| 2026-07-24 | 首页改为全屏绘制并使用运行时安全区 inset 放置来源轨道，顶部材质真正覆盖状态栏区域；iOS 26 隐藏系统 Tab Bar 的整宽自动背景，以应用 grouped background 延伸到屏幕底部，同时保留系统 Liquid Glass Tab 控件。 |
| 2026-07-24 | 顶层改为系统 `TabView` 同时管理四 Tab 状态和视觉，新增“历史”第三 Tab；iOS 26 使用系统 Liquid Glass Tab Bar、滚动收缩与 bottom accessory，旧系统使用材质降级。移除自定义 Dock 和其安全区容器，空 accessory 不再产生额外白边；首页状态栏改为 grouped background 上的渐隐模糊。新增不含图片和凭据的本机发布历史持久化、筛选、删除、清空与串跳转。 |
| 2026-07-24 | 收紧首页顶部轨道与 Feed 首卡间距：content margin 与 48pt 轨道加 6pt 顶距严格对齐；发布按钮改为轨道内部固定 40pt 的圆形交互玻璃，避免突出容器轮廓。 |
| 2026-07-23 | 合并首页系统标题栏与来源栏为单层玻璃指令轨道，并提供滚动收起后的紧凑来源胶囊；以三个常驻导航叠层和唯一透明玻璃 Dock 取代原生 TabView/Tab Bar，避免双层底栏并保留各页导航状态；串详情回复统一为 Dock accessory。 |
| 2026-07-23 | 重构滚动导航为连续进度驱动：来源轨道改为固定布局的单层悬浮玻璃，Feed content margin 随内容自然滚走，拖动期间不触发布局动画，停止后吸附到完整状态；紧凑态释放底部 Tab Bar 空间，顶部与底部不透明背板改为透明或超薄材质回退。 |
| 2026-07-23 | 落地 iOS 26 滚动感知双态导航：首页统一 Inline Title 与操作菜单，来源栏按 32/16pt 迟滞阈值收缩/恢复；引入 Liquid Glass、safe area bar 与 Soft Scroll Edge Effect；串详情回复迁移到可随 Tab Bar 自适应的底部 accessory，旧系统保留材质与安全区降级。 |
| 2026-07-23 | 将版块选择合并到首页：移除独立版块 Tab，新增可横向滚动的综合线/常驻版块来源条和统一动态 toolbar；管理 sheet 支持搜索、添加、移除与拖动排序，常驻数量不设上限；各来源继续复用 `AppSessionStore` 缓存的独立分页会话。 |
| 2026-07-23 | 重构顶层信息架构：首个 Tab 更名为“首页”并仅展示综合时间线；版块改为可搜索目录并 push 进入版块 Feed；移除重复的横向版块分页和 `MainFeedChromeModel`；帖子与回复改为无头像高密度布局，同时保留时间线切换、公告、跳页、串号直达、发串、订阅、只看 PO、回复和版块管理能力。 |
| 2026-07-22 | 建立 `XdnmbAPIClient` 依赖边界与 App composition root；引入 `AppSessionStore`、统一 `ThreadListStore`、`ThreadStore` 与 `ComposerStore`；时间线、版块、订阅、串详情、订阅操作及发帖工作流迁移到 Store；列表返回依赖原生导航滚动保留；新增状态生命周期测试。 |
