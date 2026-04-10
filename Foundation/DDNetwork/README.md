# DDNetwork

`DDNetwork` 是一个基于 `URLSession + async/await` 的轻量级 Swift 网络库。

目标是提供一套：

- 足够轻
- 易于理解
- 便于扩展
- 与业务解耦

的网络基础设施。

它当前只承载**通用网络能力**，不包含任何 WeChat 业务接口定义。

## 设计目标

- 使用 `async/await`，避免回调地狱
- 用 `NetEndpoint` 描述接口，而不是在业务层散落 `URLRequest`
- 支持全局默认 header / query / timeout / 编解码策略
- 支持认证、重试、响应拦截等扩展
- 支持请求取消（基于 Swift Concurrency cooperative cancellation）
- 支持请求开始、成功、失败、重试、取消的日志观察
- 业务模块只依赖发送能力，不直接依赖 `URLSession`

## 目录结构

```text
DDNetwork
├── Core
│   ├── NetAPI.swift          # 默认发送器实现
│   ├── NetSendable.swift     # 发送能力协议 + HTTPMethod + NetError
│   ├── NetLoggable.swift     # 日志观察协议
│   └── Endpoint.swift        # NetEndpoint 接口描述协议
├── Build
│   ├── ReqBuilder.swift      # URLRequest 构建器
│   └── RespDecoder.swift     # 响应 JSON 解码器
├── Interceptors
│   ├── NetInterceptable.swift # 拦截器协议（请求 + 响应 + 重试）
│   └── AuthInterceptor.swift  # Token 注入拦截器
└── Models
    ├── NetConfig.swift        # 全局网络配置
    ├── APIResp.swift          # 通用业务响应信封
    └── EmptyResp.swift        # 空响应模型
```

## 核心概念

### `NetEndpoint`

`NetEndpoint` 用来描述一个接口本身：

- 路径（path）
- 方法（method）
- headers
- query
- body
- 是否需要鉴权（requiresAuth）
- 关联的响应类型（Response）

业务模块应该通过实现 `NetEndpoint` 来声明接口，而不是自己拼 `URLRequest`。

示例（struct-per-endpoint 模式，推荐）：

```swift
struct GetProfile: NetEndpoint {
    typealias Response = APIResp<UserProfileDTO>
    let path = "/profile/me"
    let method: HTTPMethod = .get
}
```

### `NetSendable`

`NetSendable` 是发送能力协议：

```swift
public protocol NetSendable {
    func send<E: NetEndpoint>(_ endpoint: E) async throws -> E.Response
}
```

业务层建议依赖这个协议，而不是依赖具体实现。

### `NetAPI`

`NetAPI` 是默认可用的发送器实现，负责：

- 使用 `ReqBuilder` 构建 `URLRequest`
- 执行请求拦截器链（adapt）
- 触发日志观察
- 使用 `URLSession` 发请求
- 执行响应拦截器链（didReceive）
- 使用 `RespDecoder` 解码响应
- 在需要时尝试重试（受 `maxRetryCount` 限制）
- 支持 Task 取消检查

### `NetConfig`

`NetConfig` 提供全局网络配置：

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `baseURL` | 基础 URL | 必填 |
| `defaultHeaders` | 默认请求头 | `[:]` |
| `commonQueryItems` | 公共查询参数 | `[]` |
| `timeoutInterval` | 请求超时时间（秒） | `30` |
| `maxRetryCount` | 单个请求最大重试次数 | `3` |
| `encoder` | JSON 编码器 | `JSONEncoder()` |
| `decoder` | JSON 解码器 | `JSONDecoder()` |

### `NetInterceptable`

拦截器协议，提供三个扩展点：

| 方法 | 阶段 | 说明 |
|------|------|------|
| `adapt` | 请求前 | 修改 `URLRequest`（如注入 Token） |
| `didReceive` | 响应后 | 处理响应数据（如解密、注入） |
| `retry` | 失败后 | 决定是否重试 |

三个方法都有默认实现，按需覆盖即可。

当前内置实现：

- `AuthInterceptor`：基于闭包的 Token 注入，支持自定义 header 字段和值格式

### `NetLoggable`

独立于拦截器的日志观察协议，提供以下事件：

- `didStart` — 请求发出
- `didSucceed` — 请求成功
- `didFail` — 请求失败
- `didRetry` — 请求重试
- `didCancel` — 请求取消

所有方法都有空默认实现，按需覆盖。

### `NetError`

统一错误类型：

| Case | 说明 |
|------|------|
| `invalidURL` | URL 构建失败 |
| `invalidResponse` | 响应非 HTTPURLResponse |
| `transport(Error)` | 网络传输错误 |
| `server(statusCode:data:)` | HTTP 非 2xx 响应 |
| `decoding(Error)` | JSON 解码失败 |
| `businessError(code:message:)` | 业务层 code 非成功 |

实现了 `LocalizedError`，可直接使用 `error.localizedDescription`。

## 响应模型

### `APIResp`

用于描述常见的业务响应包裹结构：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

DDNetwork 只提供这个模型定义（知道"响应长什么样"），不解释 code 的含义（不知道"响应意味着什么"）。业务 code 的判断由上层（如 WeChatNetAPI）负责。

### `EmptyResp`

用于没有实际响应体的接口：

```swift
struct Logout: NetEndpoint {
    typealias Response = APIResp<EmptyResp>
    let path = "/auth/logout"
    let method: HTTPMethod = .post
}
```

## 请求取消

基于 Swift Concurrency 的 cooperative cancellation，无需额外 API：

```swift
let task = Task {
    let profile = try await net.send(GetProfile())
}

// 需要取消时
task.cancel()
```

`NetAPI` 内部在发送前和重试前都会检查 `Task.checkCancellation()`，`URLSession.data(for:)` 本身也支持 Task 取消。

## 推荐约定

### 推荐做的

- 业务模块用 struct-per-endpoint 模式定义接口
- 页面层依赖 `Service` 或 `ViewModel`，不直接调用网络
- 通用静态 header 放进 `NetConfig`
- 动态 token / trace / 签名放进 `NetInterceptable`
- 请求日志放进 `NetLoggable`

### 不推荐做的

- 在 `ViewController` 里直接写 `URLSession`
- 把业务接口定义写进 `DDNetwork`
- 每个接口自己重复拼默认 header
- 把 token 直接散落在 `NetEndpoint` 里
- 用 enum 定义大量接口（switch 爆炸、Response 类型共享问题）
