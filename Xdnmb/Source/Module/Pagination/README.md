# Pagination Controller Module

## 架构概述

本模块实现了基于 VIPER 原则的分页组件，包含以下核心概念：

### 1. Service（服务）
- **定义**：不包含 UI 的纯逻辑组件
- **实现**：`PaginationService`
- **职责**：
  - 管理分页状态（当前页、总页数）
  - 提供页面导航方法（上一页、下一页、跳转）
  - 验证页码有效性

### 2. Context（上下文）
- **定义**：Service 的数据模型
- **实现**：`PaginationContext` struct
- **职责**：
  - 存储分页状态数据
  - 提供状态变更方法

### 3. View（视图）
- **定义**：包含 UI 的视图组件
- **实现**：`PaginationControlView`
- **职责**：
  - 显示分页信息（当前页、总页数）
  - 提供用户交互控件（输入框、按钮）
  - 响应更新指令，刷新 UI

### 4. ViewModel（视图模型）
- **定义**：View 的展示数据
- **实现**：`PaginationViewModel`
- **职责**：
  - 根据 Context 生成 UI 展示文本
  - 保证 View 只展示格式化的数据

### 5. Controller（控制器）
- **定义**：协调 Service 和 View 的独立组件
- **实现**：`PaginationController`
- **职责**：
  - 绑定 View 事件（按钮点击）
  - 调用 Service 更新状态
  - 同步 View 和 Context
  - 向外部通知状态变化

## 类关系图

```
┌────────────────────────────────────────┐
│  ArchitectureProtocols                  │
├────────────────────────────────────────┤
│ - ServiceProtocol                       │
│ - ViewProtocol                          │
│ - ControllerProtocol                    │
│ - AbstractController<V, C>              │
└────────────────────────────────────────┘
         △
         │ implements
         │
┌────────────────────────────────────────┐
│  PaginationService                      │
├────────────────────────────────────────┤
│ - context: PaginationContext            │
│ - nextPage()                            │
│ - previousPage()                        │
│ - jumpToPage()                          │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│  PaginationControlView                  │
├────────────────────────────────────────┤
│ - pageInfoLabel                         │
│ - pageInputTextField                    │
│ - jumpButton                            │
│ - prevButton                            │
│ - nextButton                            │
│ + updateUI(with:)                       │
└────────────────────────────────────────┘
         △
         │ uses
         │
┌────────────────────────────────────────┐
│  PaginationController                   │
├────────────────────────────────────────┤
│ - view: PaginationControlView           │
│ - context: PaginationContext            │
│ + onPageChanged                         │
│ + onError                               │
│ - onJumpButtonTapped()                  │
│ - onPrevButtonTapped()                  │
│ - onNextButtonTapped()                  │
└────────────────────────────────────────┘
```

## 使用示例

### 1. 创建分页控制器

```swift
let paginationController = PaginationController(
    view: PaginationControlView(),
    context: PaginationContext()
)
```

### 2. 设置事件回调

```swift
paginationController.onPageChanged = { [weak self] page in
    self?.loadDataForPage(page)
}

paginationController.onError = { [weak self] message in
    self?.showAlert(message: message)
}
```

### 3. 在视图控制器中集成

```swift
view.addSubview(paginationController.view)
paginationController.view.snp.makeConstraints { make in
    make.top.left.right.equalToSuperview()
    make.height.equalTo(60)
}
```

### 4. 更新总页数（通常来自 API 响应）

```swift
if let totalPages = apiResponse.totalPages {
    paginationController.updateTotalPages(totalPages)
}
```

## 优势

1. **解耦合**
   - Service 与 View 完全独立
   - Controller 协调两者交互
   - 通过回调通知外部

2. **可测试性**
   - Service 可单独测试（无 UI 依赖）
   - View 可 mock 测试
   - Controller 逻辑清晰易测

3. **可复用性**
   - PaginationController 可用于任何需要分页的场景
   - 只需提供不同的 onPageChanged 回调
   - UI 样式可自定义（PaginationControlView）

4. **可维护性**
   - 职责清晰
   - 代码结构规范
   - 易于扩展和修改

## 扩展示例

### 添加其他功能

```swift
// 重置分页
paginationController.reset()

// 获取当前页
let currentPage = paginationController.getCurrentPage()

// 直接修改上下文
paginationController.context.currentPage = 5
```

### 自定义 View

```swift
class CustomPaginationView: UIView, PaginationViewProtocol {
    // 实现自己的 UI
    func updateUI(with viewModel: PaginationViewModel) {
        // 自定义更新逻辑
    }
    
    func clearInputField() {
        // 自定义清空逻辑
    }
}

let controller = PaginationController(
    view: CustomPaginationView(),
    context: PaginationContext()
)
```

## 文件结构

```
Source/
├── Architecture/
│   └── ArchitectureProtocols.swift      # 基础协议定义
└── Module/
    └── Pagination/
        ├── PaginationArchitecture.swift # 分页模块完整实现
        └── README.md                    # 文档
```

## 下一步计划

- [ ] 添加分页样式主题支持
- [ ] 支持自定义按钮样式
- [ ] 支持不同的页码输入方式
- [ ] 添加单元测试
- [ ] 添加 UI 测试
