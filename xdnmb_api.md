# X岛匿名版 API 文档

> 来源仓库：https://github.com/orzogc/xdnmb_api  
> 协议：非官方逆向整理，仅供学习与个人使用

---

## 目录

- [基础信息](#基础信息)
- [认证](#认证)
- [图片 CDN](#图片-cdn)
- [接口列表](#接口列表)
  - [站点信息](#站点信息)
  - [版块与时间线](#版块与时间线)
  - [串（Thread）](#串thread)
  - [订阅（Feed）](#订阅feed)
  - [发帖与回复](#发帖与回复)
  - [账号与饼干管理](#账号与饼干管理)
- [数据结构](#数据结构)
- [错误处理](#错误处理)
- [附录：静态数据](#附录静态数据)

---

## 基础信息

| 项目 | 值 |
|------|----|
| 主域名 | `https://www.nmbxd1.com/`（实际请求前应先跟随 `https://www.nmbxd.com/` 的重定向） |
| 备用 API | `https://api.nmb.best/` |
| CDN 基础 | `https://image.nmb.best/` |
| 响应格式 | JSON（`Api/*` 路径），HTML（`Forum/*`、`Member/*`、`Home/*` 路径需自行解析） |
| 字符编码 | UTF-8（响应头可能缺少编码声明，需按 UTF-8 强制解码） |
| 分页起始 | 所有分页从第 **1** 页开始，每页 **20** 条 |
| 时区 | 时间字符串为 **CST（UTC+8）**，格式 `YYYY-MM-DD HH:MM:SS` |

### 动态发现基础 URL

正式使用前，建议通过以下流程获取当前有效地址：

1. `GET https://www.nmbxd.com/` → 跟随 HTTP 重定向，最终落点即为当前主基础 URL
2. `GET {base}/Api/getCdnPath` → 获取 CDN 节点列表
3. `GET {base}/Api/backupUrl` → 获取备用 API 地址列表

---

## 认证

X岛使用"饼干"（Cookie）机制标识用户身份。

| Cookie 名 | 说明 |
|-----------|------|
| `userhash` | 用户身份标识，格式：`userhash={hash}` |
| `PHPSESSID` | PHP 会话 ID，登录后由服务器通过 `Set-Cookie` 下发，后续请求需携带 |

**使用方式**：将需要的 Cookie 合并后放入请求头：

```
Cookie: userhash=abc123; PHPSESSID=xyz789
```

- 匿名浏览（版块、串）：**不需要**认证
- 发帖、回复、订阅操作：**需要** `userhash`
- 饼干管理操作：**需要** `PHPSESSID`（即先调用登录接口）

---

## 图片 CDN

图片哈希（`img`）和后缀（`ext`）来自帖子数据。

| 图片类型 | URL 格式 |
|----------|---------|
| 缩略图 | `{cdnUrl}thumb/{img}{ext}` |
| 原图 | `{cdnUrl}image/{img}{ext}` |

**示例**：

```
缩略图：https://image.nmb.best/thumb/2024/01/01/abc123.jpg
原图：  https://image.nmb.best/image/2024/01/01/abc123.jpg
```

发帖支持的图片格式：`image/jpeg`、`image/png`、`image/gif`

---

## 接口列表

---

### 站点信息

#### 获取站点公告

```
GET https://nmb.ovear.info/nmb-notice.json
```

**认证**：不需要

**响应**（JSON 对象）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `content` | string | 公告正文（HTML） |
| `date` | string | 公告日期 |
| `enable` | boolean | 公告是否生效 |

---

#### 获取 CDN 节点列表

```
GET {base}/Api/getCdnPath
```

**认证**：不需要

**响应**（JSON 数组）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `url` | string | CDN 基础地址（URL） |
| `rate` | integer | 速率权重，值越大优先级越高 |

**示例响应**：

```json
[
  { "url": "https://image.nmb.best/", "rate": 10 },
  { "url": "https://img1.nmb.best/", "rate": 8 }
]
```

---

#### 获取备用 API 地址

```
GET {base}/Api/backupUrl
```

**认证**：不需要

**响应**（JSON 数组，字符串）：备用 API URL 列表。

---

### 版块与时间线

#### 获取版块列表

```
GET {base}/Api/getForumList
```

**认证**：不需要

**响应**（JSON 数组，每项为版块分组 `ForumGroup`）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 分组 ID |
| `sort` | integer | 排序权重 |
| `name` | string | 分组名称 |
| `status` | string | 分组状态（`n` = 正常） |
| `forums` | array\<Forum\> | 该分组下的版块列表，见 [Forum](#forum) |

---

#### 获取时间线列表

```
GET {base}/Api/getTimelineList
```

**认证**：不需要

**响应**（JSON 数组，每项为 `Timeline`）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 时间线 ID |
| `name` | string | 名称 |
| `display_name` | string | 显示名称 |
| `notice` | string | 简介 |
| `max_page` | integer | 最大页数（固定为 20） |

---

#### 获取版块帖子列表（JSON）

```
GET {base}/Api/showf?id={forumId}&page={page}
```

**认证**：不需要

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | integer | 是 | 版块 ID |
| `page` | integer | 否 | 页码，默认 `1` |

**响应**（JSON 数组，每项为 `ForumThread`）：见 [ForumThread](#forumthread)

---

#### 获取版块帖子列表（HTML）

```
GET {base}/Forum/showf?id={forumId}&page={page}
```

**认证**：不需要  
**响应**：HTML 页面，需自行解析

---

#### 获取时间线帖子列表

```
GET {base}/Api/timeline?id={timelineId}&page={page}
```

**认证**：不需要

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | integer | 是 | 时间线 ID |
| `page` | integer | 否 | 页码，默认 `1` |

**响应**（JSON 数组，每项为 `ForumThread`）：见 [ForumThread](#forumthread)

---

### 串（Thread）

#### 获取完整串

```
GET {base}/Api/thread?id={mainPostId}&page={page}
```

**认证**：不需要

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | integer | 是 | 主楼帖子 ID |
| `page` | integer | 否 | 页码，默认 `1` |

**响应**（JSON 对象，`Thread`）：见 [Thread](#thread)

---

#### 获取串（只看 Po）

```
GET {base}/Api/po?id={mainPostId}&page={page}
```

**认证**：不需要  
**查询参数**：同 [获取完整串](#获取完整串)  
**响应**：同 [Thread](#thread)，但 `Replies` 仅包含 Po 主的回复

---

#### 获取引用（JSON）

```
GET {base}/Api/ref?id={postId}
```

**认证**：不需要

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | integer | 是 | 被引用的帖子 ID |

**响应**（JSON 对象）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 帖子 ID |
| `img` | string | 图片哈希（无图为空字符串） |
| `ext` | string | 图片后缀（如 `.jpg`） |
| `now` | string | 发帖时间（CST） |
| `user_hash` | string | 用户哈希 |
| `name` | string | 用户名 |
| `title` | string | 标题 |
| `content` | string | 正文（HTML） |
| `sage` | integer | 是否 Sage（`1` = 是） |
| `status` | string | 帖子状态 |
| `admin` | integer | 是否管理员（`1` = 是） |

---

#### 获取引用（HTML）

```
GET {base}/Home/Forum/ref?id={postId}
```

**认证**：不需要  
**响应**：HTML 片段，需自行解析

---

#### 获取最近发送的帖子

```
GET {base}/Api/getLastPost
```

**认证**：需要 `userhash`

**响应**（JSON 对象）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `resto` | integer | 所属主楼 ID（`0` 表示该帖即为主楼） |
| `id` | integer | 帖子 ID |
| `now` | string | 发帖时间（CST） |
| `user_hash` | string | 用户哈希 |
| `name` | string | 用户名 |
| `email` | string | 邮箱 |
| `title` | string | 标题 |
| `content` | string | 正文（HTML） |
| `sage` | integer | 是否 Sage |
| `admin` | integer | 是否管理员 |

---

### 订阅（Feed）

`feedId` 为 UUID 字符串，唯一标识用户的订阅列表。

#### 获取订阅列表（JSON）

```
GET {base}/Api/feed?uuid={feedId}&page={page}
```

**认证**：不需要（但 feedId 需自行保管）

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `uuid` | string | 是 | 订阅列表 UUID |
| `page` | integer | 否 | 页码，默认 `1` |

**响应**（JSON 数组，每项为 `Feed`）：见 [Feed](#feed)

---

#### 获取订阅列表（HTML）

```
GET {base}/Forum/feed/page/{page}.html
```

**认证**：需要 `userhash`（通过 Cookie）  
**响应**：HTML 页面，需自行解析

---

#### 添加订阅（JSON）

```
GET {base}/Api/addFeed?uuid={feedId}&tid={mainPostId}
```

**认证**：需要 `userhash`

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `uuid` | string | 是 | 订阅列表 UUID |
| `tid` | integer | 是 | 要订阅的主楼 ID |

**响应**：纯文本，成功返回 `"订阅大成功！"` 类似字符串

---

#### 添加订阅（HTML）

```
GET {base}/Home/Forum/addFeed/tid/{mainPostId}.html
```

**认证**：需要 `userhash`  
**响应**：HTML，需自行解析

---

#### 取消订阅（JSON）

```
GET {base}/Api/delFeed?uuid={feedId}&tid={mainPostId}
```

**认证**：需要 `userhash`

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `uuid` | string | 是 | 订阅列表 UUID |
| `tid` | integer | 是 | 要取消订阅的主楼 ID |

**响应**：纯文本

---

#### 取消订阅（HTML）

```
GET {base}/Home/Forum/delFeed/tid/{mainPostId}.html
```

**认证**：需要 `userhash`  
**响应**：HTML，需自行解析

---

### 发帖与回复

#### 获取验证码图片

```
GET {base}/Member/User/Index/verify.html
```

**认证**：需要 `PHPSESSID`（先登录）  
**响应**：图片二进制数据（PNG/JPEG）

---

#### 发新帖

```
POST {base}/Home/Forum/doPostThread.html
Content-Type: multipart/form-data
```

**认证**：需要 `userhash`（Cookie）

**请求字段**（`multipart/form-data`）：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `fid` | integer | 是 | 目标版块 ID |
| `content` | string | 是 | 帖子正文 |
| `name` | string | 否 | 发帖人名称（默认"无名氏"） |
| `email` | string | 否 | 邮箱字段（通常留空） |
| `title` | string | 否 | 帖子标题（通常留空） |
| `water` | string | 否 | 是否添加水印（`"true"` 或 `"false"`） |
| `image` | file | 否 | 附图，MIME 类型须为 `image/jpeg`、`image/png` 或 `image/gif` |

**响应**：纯文本或 HTML，成功时服务器会重定向

**客户端处理**：发新帖响应不保证直接包含主楼 ID。客户端在确认提交成功后，使用同一 `userhash` 调用 `Api/getLastPost`，以 `resto > 0 ? resto : id` 解析可导航的主楼 ID，用于本机发布历史；查询失败不应把已经成功的发帖回报为失败。

---

#### 回复帖子

```
POST {base}/Home/Forum/doReplyThread.html
Content-Type: multipart/form-data
```

**认证**：需要 `userhash`（Cookie）

**请求字段**（`multipart/form-data`）：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `resto` | integer | 是 | 要回复的主楼 ID |
| `content` | string | 是 | 回复正文 |
| `name` | string | 否 | 发帖人名称 |
| `email` | string | 否 | 邮箱字段 |
| `title` | string | 否 | 标题 |
| `water` | string | 否 | 是否添加水印 |
| `image` | file | 否 | 附图（格式同发帖） |

**响应**：纯文本或 HTML

---

### 账号与饼干管理

以下接口均需要有效的 `PHPSESSID`（通过登录接口获取）。

#### 用户登录

```
POST {base}/Member/User/Index/login.html
Content-Type: application/x-www-form-urlencoded
```

**认证**：不需要（登录本身）

**请求字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `email` | string | 是 | 注册邮箱 |
| `password` | string | 是 | 密码 |
| `verify` | string | 是 | 验证码（先调用验证码接口获取） |

**响应**：HTML。登录成功后，服务器通过 `Set-Cookie: PHPSESSID=...` 下发会话 ID。

---

#### 注册账号

```
POST {base}/Member/User/Index/sendRegister.html
Content-Type: application/x-www-form-urlencoded
```

**认证**：不需要

**请求字段**：email、password 等（具体字段参照站点注册页面）

---

#### 重置密码

```
POST {base}/Member/User/Index/sendForgotPassword.html
Content-Type: application/x-www-form-urlencoded
```

**认证**：不需要

---

#### 查看饼干列表

```
GET {base}/Member/User/Cookie/index.html
```

**认证**：需要 `PHPSESSID`  
**响应**：HTML，需自行解析。包含以下信息：

| 信息 | 说明 |
|------|------|
| `canGetCookie` | 是否还能申请新饼干 |
| `currentCookieCount` | 当前持有饼干数量 |
| `totalCookieCount` | 历史总申请数量 |
| `cookieIdList` | 饼干 ID 列表（integer 数组） |

---

#### 申请新饼干

```
POST {base}/Member/User/Cookie/apply.html
Content-Type: application/x-www-form-urlencoded
```

**认证**：需要 `PHPSESSID`

**请求字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `verify` | string | 是 | 验证码 |

**响应**：HTML

---

#### 导出（获取）指定饼干

```
GET {base}/Member/User/Cookie/export/id/{cookieId}.html
```

**认证**：需要 `PHPSESSID`

**路径参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `cookieId` | integer | 饼干 ID |

**响应**：HTML 或 JSON，包含 `userHash`、`name`、`id` 字段。

解析结果（`XdnmbCookie`）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `userHash` | string | 饼干哈希值，即 `userhash` 的值 |
| `name` | string \| null | 饼干名称 |
| `id` | integer \| null | 饼干 ID |

---

#### 删除指定饼干

```
POST {base}/Member/User/Cookie/delete/id/{cookieId}.html
Content-Type: application/x-www-form-urlencoded
```

**认证**：需要 `PHPSESSID`

**路径参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `cookieId` | integer | 饼干 ID |

**请求字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `verify` | string | 是 | 验证码 |

**响应**：HTML

---

## 数据结构

### Forum

版块信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 版块 ID |
| `fgroup` | integer | 所属分组 ID |
| `sort` | integer | 排序权重 |
| `name` | string | 版块名称 |
| `showName` | string | 显示名称（可能与 `name` 不同） |
| `msg` | string | 版块简介 |
| `interval` | integer | 发帖间隔（秒） |
| `safe_mode` | integer | 安全模式（`0`/`1`） |
| `auto_delete` | integer | 自动删除（`0`/`1`） |
| `thread_count` | integer | 帖子总数（用于计算最大页数） |
| `permission_level` | integer | 发帖所需权限等级 |
| `forum_fuse_id` | integer | 融合版块 ID |
| `createdAt` | string | 创建时间 |
| `updateAt` | string | 更新时间 |
| `status` | string | 状态（`n` = 正常） |

> **maxPage 计算**：`min(ceil(thread_count / 20), 100)`

---

### Post

单条帖子/回复。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 帖子 ID |
| `fid` | integer | 所属版块 ID |
| `ReplyCount` | integer | 回复数量 |
| `img` | string | 图片哈希（无图为空字符串） |
| `ext` | string | 图片后缀（如 `.jpg`，无图为空） |
| `now` | string | 发帖时间（CST，格式 `YYYY-MM-DD HH:MM:SS`） |
| `user_hash` | string | 用户哈希 |
| `name` | string | 发帖人名称（通常为"无名氏"） |
| `title` | string | 标题（通常为"无标题"） |
| `content` | string | 正文（HTML，可能含 `>>No.xxxxx` 引用） |
| `sage` | integer | 是否 Sage（`1` = 是，`0` = 否） |
| `admin` | integer | 是否管理员（`1` = 是） |
| `Hide` | integer | 是否隐藏（`1` = 是） |

---

### ForumThread

版块列表中的串（主楼 + 最近回复预览）。

除 [Post](#post) 的所有字段外，还包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `Replies` | array\<Post\> | 最近回复列表（最多 5 条） |
| `RemainReplies` | integer | 剩余未展示的回复数量 |

**示例**：

```json
{
  "id": 12345,
  "fid": 4,
  "ReplyCount": 120,
  "img": "2024/01/01/abc123",
  "ext": ".jpg",
  "now": "2024-01-01 12:00:00",
  "user_hash": "Ab1Cd2Ef",
  "name": "无名氏",
  "title": "无标题",
  "content": "这是楼主内容",
  "sage": 0,
  "admin": 0,
  "Hide": 0,
  "Replies": [
    {
      "id": 12350,
      "fid": 4,
      "ReplyCount": 0,
      "img": "",
      "ext": "",
      "now": "2024-01-01 12:05:00",
      "user_hash": "Gh3Ij4Kl",
      "name": "无名氏",
      "title": "无标题",
      "content": "这是回复内容",
      "sage": 0,
      "admin": 0,
      "Hide": 0
    }
  ],
  "RemainReplies": 115
}
```

---

### Thread

完整串（主楼 + 当前页回复）。

| 字段 | 类型 | 说明 |
|------|------|------|
| *(主楼字段)* | — | 同 [Post](#post) |
| `fid` | integer | 所属版块 ID（Thread 层级字段） |
| `Replies` | array\<Post\> | 当前页的回复列表（每页最多 19 条） |

> **maxPage 计算**：`ceil(ReplyCount / 19)`  
> **当前页**：由请求时的 `page` 参数决定

---

### Feed

订阅列表中的条目。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | integer | 主楼 ID |
| `user_id` | string | 用户 ID |
| `fid` | integer | 版块 ID |
| `reply_count` | integer | 回复数 |
| `recent_replies` | array | 最近回复（结构同 Post） |
| `category` | string | 分类 |
| `file_id` | string | 文件 ID |
| `img` | string | 图片哈希 |
| `ext` | string | 图片后缀 |
| `now` | string | 发帖时间（CST） |
| `user_hash` | string | 用户哈希 |
| `name` | string | 用户名 |
| `email` | string | 邮箱 |
| `title` | string | 标题 |
| `content` | string | 正文（HTML） |
| `status` | string | 状态 |
| `admin` | integer | 是否管理员 |
| `hide` | integer | 是否隐藏 |
| `po` | string | Po 主标识 |

---

## 错误处理

### HTTP 层面

所有接口期望返回 HTTP `200 OK`。其他状态码均视为错误：

| 状态码 | 含义 |
|--------|------|
| `4xx` | 请求错误（参数缺失、认证失败等） |
| `5xx` | 服务器错误 |

### 业务层面（JSON API）

部分 `Api/*` 接口在请求失败时会返回包含错误信息的 JSON 对象，格式：

```json
{ "success": false, "message": "错误原因描述" }
```

或直接返回包含错误说明的纯文本。

---

## 附录：静态数据

### 颜文字列表

客户端内置约 100 个颜文字，供发帖时引用，结构：

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 颜文字名称 |
| `text` | string | 颜文字文本 |

**部分示例**：

| name | text |
|------|------|
| 表情1 | `(╯°□°）╯︵ ┻━┻` |
| 表情2 | `(=・ω・=)` |
| 表情3 | `ヽ(°▽°)ノ` |

---

### 举报原因

发帖时可通过 `reportId` 字段附带举报信息，共 8 类：

| ID | 名称 |
|----|------|
| 1 | 违规内容（色情/暴力等） |
| 2 | 广告/刷屏 |
| 3 | 侵权 |
| 4 | 政治敏感 |
| 5 | 人身攻击 |
| 6 | 谣言/虚假信息 |
| 7 | 其他违规 |
| 8 | 举报饼干 |

> 注意：以上 ID 和名称为示意，实际值请参考 `ReportReason.list` 源码。

---

*文档整理自 https://github.com/orzogc/xdnmb_api 源码，如有变更请以源码为准。*
