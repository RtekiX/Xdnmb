<!--
  AGENTS.md
  Author: Maru
-->

# Xdnmb Repository Instructions

修改本仓库时必须遵守以下规则：

1. 完整阅读并遵守根目录 `DEVELOPMENT_STANDARDS.md`。
2. 架构、模块、状态生命周期、导航、缓存或用户功能变化，必须在同一改动中更新 `CODE_ARCHITECTURE.md`。
3. API、认证、请求参数或响应模型变化，必须同步 `xdnmb_api.md`。
4. 新文件必须在首行加入作者为 `Maru` 的文件头。
5. Feature 与 Module 禁止直接使用 `APIService.shared`；通过 `XdnmbAPIClient` 注入。
6. 提交前运行相关状态测试、Debug/Release 构建、`git diff --check` 和架构约束检查。
