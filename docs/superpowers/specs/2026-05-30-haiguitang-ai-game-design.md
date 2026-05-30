# 海龟汤 AI 小游戏(GameModule L2 模式)设计文档

**日期**:2026-05-30
**范围**:在现有 GameModule(H5 大厅 + WebView 小游戏 + OSS 动态化)之上,落地 **GameModule 文档第十四节预留的 "L2 模式"** —— 引入最小 JS Bridge,让 H5 小游戏调用原生 AI 能力;首个 AI 游戏为「海龟汤(情景推理)」。
**目标**:做一款"语言即玩法"的生成式 AI 小游戏,作为简历"混合架构 + LLM 应用工程"的示例。

---

## 一、背景与目标

### 现状

GameModule 已落地"微信小游戏"形态:游戏厅(hall.html)→ OSS 下发 zip → `WKWebView`(GameRunner)加载本地 `file://` 跑纯 web 游戏。大厅 → 游戏的跳转走 **URL scheme 拦截**,**没有 JS Bridge**(纯 web 自闭环)。GameModule 设计文档第十四节明确预留:要做 AI 对战类游戏,需"加最小 JS Bridge,Native 转发 Claude API,API key 走 Keychain"。

### 目标

1. **最小 JS Bridge**:H5 ↔ 原生的异步请求/响应通道(`WCGameBridge.call(method, params) → Promise`),通用、可扩展(本期只接 `ai.*`,未来可加 `im.*` 等)。
2. **原生 AIKit**:可插拔 AI 能力层,`AIProvider` 协议 + `ClaudeProvider`(直连 Anthropic 或本地代理)+ `MockProvider`(零成本测试)。
3. **HaiguitangService**:海龟汤的会话状态机 + prompt 拼装 + 结构化裁判结果解析。**汤底只存原生层,绝不下发到 H5**(防作弊)。
4. **生成式无限关卡**:开局让 Claude 现场生成「汤面 + 汤底」,汤底持久化在原生会话,后续每次判定都带上汤底上下文,保证前后一致。
5. **haiguitang H5 bundle**:跑在现有 GameRunner 里,复用整套 OSS 下发/更新机制。
6. **演示可零成本**:`MockProvider` 让整局游戏能在单测/CI 跑通,不花 API 费;开发可用本地代理蹭 Claude Max。

### 非目标

- 流式输出(海龟汤回答短:"是/不是/无关",本期用请求-响应即可;汤面揭晓的流式动画放 Phase 3 可选)。
- 多人对战 / 排行榜 / 分享到 IM(超出范围;Bridge 已为未来 `im.*` 留口)。
- 固定本地题库(明确采用**生成式**关卡,题库方案不做)。
- 强化 Bridge 成完整框架(只做满足 `ai.*` 的最小可用版本)。

### 简历卖点

- **混合架构**:自研最小 JS Bridge,H5 小游戏通过 Bridge 调用原生 AI 能力 —— 微信小游戏 + AI 的真实工程范式。
- **可插拔 AI Provider 抽象层**:`AIProvider` 协议屏蔽多后端(Anthropic 直连 / 本地代理 / Mock),支持运行时切换与降级。
- **LLM 结构化输出 + 严格规则约束**:用 JSON schema 把 LLM 约束成"生成式裁判",解析守卫 + 重试 + 安全降级。
- **生成式无限关卡 + 状态一致性 / 防作弊**:汤底服务端持久化、不下发,带历史上下文保证判定一致。

---

## 二、模块划分

```
HelloRN/
├── WeChatSwift/Modules/
│   ├── WeChatKit/
│   │   └── AIKit/                         ← 新建 Pod:可复用 AI 能力层
│   └── Business/GameModule/
│       ├── Bridge/                        ← 新建:最小 JS Bridge + ai.* handler
│       └── Haiguitang/                    ← 新建:海龟汤会话服务(原生侧)
└── WeChatGames/
    └── haiguitang/                        ← 新建:海龟汤 H5 前端 bundle
```

**依赖方向**:
- `AIKit` → `WeChatNetAPI`(复用 `APIClient`/`NetEndpoint`/拦截器)。不依赖任何业务模块。
- `GameModule.Bridge` / `GameModule.Haiguitang` → `AIKit`、`WeChatRouter`、`SnapKit`。
- H5 bundle 不依赖任何原生代码,只约定 Bridge 协议。

### 新增/改动文件

```
Modules/WeChatKit/AIKit/
├── AIKit.podspec
├── AIProvider.swift           # protocol:complete(_ req: AIRequest) async throws -> AIResponse
├── ClaudeProvider.swift       # Anthropic Messages API;baseURL 可配(直连 / 本地代理)
├── MockProvider.swift         # 预设响应,零成本测试/离线
├── AIClient.swift             # 持有 currentProvider,可运行时切换;统一入口
├── AIConfig.swift             # provider 选择 / baseURL / model / apiKey(Keychain)
└── Models.swift               # AIRequest / AIResponse / AIMessage / AIError

Modules/Business/GameModule/Bridge/
├── GameBridge.swift           # WKScriptMessageHandler;callId 配对 + 回调注入
├── GameBridgeHandler.swift    # protocol:handle(method, params) async -> Result
└── AIBridgeHandler.swift      # 处理 ai.* → 转发 HaiguitangService

Modules/Business/GameModule/Haiguitang/
├── HaiguitangService.swift    # 会话状态机 + prompt 拼装 + 结果解析
├── PuzzleSession.swift        # 单局状态:surface/solution(secret)/history/solved
└── HaiguitangPrompts.swift    # system prompt + 生成/判定 prompt 模板

WeChatGames/haiguitang/
├── index.html
├── main.js                    # 渲染 + 交互
├── bridge.js                  # WCGameBridge.call() Promise 封装
├── style.css
├── icon.png
└── README.md
```

GameRunnerViewController 改动:为 `haiguitang` 这类需要 Bridge 的游戏,在 WebView 配置里注册 `GameBridge`(见第七节)。

---

## 三、架构总览

```
┌──────────────────────────────────────────────────────────────┐
│  haiguitang H5 (跑在 GameRunner 的 WKWebView)                 │
│  ├─ 汤面卡片 / 问答气泡流 / 输入框 / [提示][我要解答][放弃]    │
│  └─ bridge.js: WCGameBridge.call('ai.ask', {...}) → Promise   │
└───────────────────────────┬──────────────────────────────────┘
        JS → Native: webkit.messageHandlers.WCGameBridge.postMessage
        Native → JS: webView.evaluateJS(WCGameBridge._resolve(callId,res))
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────┐
│  GameBridge (WKScriptMessageHandler)                          │
│  ├─ 解析 {callId, method, params}                             │
│  ├─ 按 method 前缀派发到 handler(ai.* → AIBridgeHandler)     │
│  └─ await 结果 → evaluateJS 回调 callId(成功/失败/超时)      │
└───────────────────────────┬──────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────┐
│  HaiguitangService (会话状态机,单例 / VC 级)                 │
│  ├─ sessions: [puzzleId: PuzzleSession]                       │
│  ├─ startPuzzle → 生成 prompt → AIClient → 存 surface+solution│
│  ├─ ask/guess/hint → 带 solution+history 拼判定 prompt        │
│  └─ 解析 LLM JSON → verdict/comment/solved(守卫+重试+降级)   │
└───────────────────────────┬──────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────┐
│  AIKit                                                        │
│  AIClient ──holds──▶ AIProvider                              │
│                       ├─ ClaudeProvider(baseURL 可配)        │
│                       │    ├─ 直连 https://api.anthropic.com  │
│                       │    └─ 本地代理 http://localhost:PORT  │
│                       └─ MockProvider(预设响应)              │
│  请求经 WeChatNetAPI 的 APIClient/NetEndpoint 发出            │
└───────────────────────────┬──────────────────────────────────┘
                                    ▼
                  Claude (Anthropic Messages API)
```

---

## 四、JS Bridge 设计(最小可用)

### 4.1 协议约定

**JS → Native**(单一消息处理器 `WCGameBridge`):
```js
window.webkit.messageHandlers.WCGameBridge.postMessage({
  callId: "c_17",          // JS 生成的唯一 id
  method: "ai.ask",        // 命名空间.动作
  params: { puzzleId, question }
});
```

**Native → JS**(执行回调,按 callId 配对):
```js
// 成功
window.WCGameBridge._resolve("c_17", { ok: true,  data: {...} });
// 失败
window.WCGameBridge._resolve("c_17", { ok: false, error: { code, message } });
```

### 4.2 bridge.js(H5 侧封装)

```js
(function () {
  const pending = {};            // callId -> {resolve, reject, timer}
  let seq = 0;

  window.WCGameBridge = {
    call(method, params, timeoutMs = 30000) {
      return new Promise((resolve, reject) => {
        const callId = "c_" + (++seq);
        const timer = setTimeout(() => {
          delete pending[callId];
          reject({ code: "TIMEOUT", message: "AI 响应超时" });
        }, timeoutMs);
        pending[callId] = { resolve, reject, timer };
        window.webkit.messageHandlers.WCGameBridge.postMessage({ callId, method, params });
      });
    },
    _resolve(callId, res) {
      const p = pending[callId];
      if (!p) return;
      clearTimeout(p.timer);
      delete pending[callId];
      res.ok ? p.resolve(res.data) : p.reject(res.error);
    }
  };
})();
```

### 4.3 ai.* 方法表

| method | params | 返回 data | 说明 |
|---|---|---|---|
| `ai.startPuzzle` | `{difficulty?, theme?}` | `{puzzleId, title, surface}` | 生成新局,**只回汤面**,汤底留原生 |
| `ai.ask` | `{puzzleId, question}` | `{verdict, comment, solved}` | 问是非题,裁判作答 |
| `ai.guess` | `{puzzleId, guess}` | `{solved, comment, solution?}` | 提交还原故事;答对回汤底 |
| `ai.hint` | `{puzzleId}` | `{hint}` | 要一条提示 |
| `ai.giveUp` | `{puzzleId}` | `{solution}` | 放弃,揭晓汤底 |

`verdict ∈ { "yes", "no", "irrelevant", "partial", "close" }` → H5 映射为「是 / 不是 / 无关 / 是也不是 / 接近真相了」。

---

## 五、AIKit 设计(可插拔)

### 5.1 协议与模型

```swift
public protocol AIProvider {
    func complete(_ request: AIRequest) async throws -> AIResponse
}

public struct AIRequest {
    public var system: String
    public var messages: [AIMessage]      // role: user/assistant
    public var maxTokens: Int
    public var temperature: Double        // 判定用低温(0.2),生成用中温(0.8)
}

public struct AIResponse {
    public let text: String               // 模型纯文本输出(期望是 JSON 串)
}

public enum AIError: Error {
    case network(Error)
    case rateLimited
    case decoding                          // 上层解析 JSON 失败时抛
    case provider(message: String)
}
```

### 5.2 实现

- **ClaudeProvider**:把 `AIRequest` 映射为 Anthropic Messages API(`/v1/messages`,`anthropic-version` 头,`x-api-key`)。`baseURL` 可配:
  - 直连:`https://api.anthropic.com`,key 取自 Keychain。
  - 本地代理:`http://localhost:PORT`(开发/演示蹭 Max,见第九节)。
  - 请求通过 `WeChatNetAPI` 的 `APIClient.sendRaw` 发(非标准 `APIResp` 包,用 raw)。
- **MockProvider**:按最后一条 user 消息内容/标记返回**预设 JSON 串**(生成局、各类 verdict、通关)。用于单测/CI/离线演示,零成本。
- 预留 `DeepSeekProvider` 等(OpenAI 兼容,本期不实现,协议已支持)。

### 5.3 AIClient

```swift
public final class AIClient {
    public static let shared = AIClient()
    private var provider: AIProvider

    public func setProvider(_ p: AIProvider)              // 运行时切换
    public func complete(_ req: AIRequest) async throws -> AIResponse
}
```

`AIConfig` 决定启动时装哪个 provider(Debug 默认本地代理/Mock,Release 默认直连),并管理 baseURL / model / Keychain key。

---

## 六、HaiguitangService 设计

### 6.1 会话状态

```swift
struct PuzzleSession {
    let puzzleId: String
    let title: String
    let surface: String            // 汤面(可下发)
    let solution: String           // 汤底(机密,绝不下发,除非 solved/giveUp)
    var history: [(q: String, verdict: String)]
    var solved: Bool
    let difficulty: String
    let theme: String?
}
```

`sessions: [String: PuzzleSession]` 持有于 service(VC 生命周期内)。汤底只在此驻留;H5/JS 永远拿不到,DevTools 也看不到 → 防作弊。

### 6.2 关卡生成(startPuzzle)

system prompt 设定"海龟汤出题人"角色 + **只输出 JSON**;user 给难度/主题。期望返回:
```json
{ "title": "...", "surface": "汤面(玩家可见的诡异情景)", "solution": "汤底(完整真相)" }
```
解析后存 session,返回 `{puzzleId, title, surface}`。生成用 `temperature 0.8`。

### 6.3 裁判(ask / guess)

每次把 **汤底 + 汤面 + 历史问答 + 本次问题** 一起喂给 Claude,要求严格输出:
```json
{ "verdict": "yes|no|irrelevant|partial|close", "comment": "≤20字、不剧透", "solved": false }
```
- 判定用 `temperature 0.2` 保持稳定;带历史保证前后一致。
- `ask`:返回 `{verdict, comment, solved}`。
- `guess`:prompt 改为"判断玩家还原的故事是否抓住关键真相",返回 `{solved, comment}`;`solved=true` 时附 `solution`。
- prompt 明确要求 comment **不得泄露汤底关键信息**。

### 6.4 解析守卫(关键鲁棒性)

```
解析 AIResponse.text 为目标 JSON:
  1. 直接 JSONDecoder
  2. 失败 → 抽取首个 {...} 子串再试(模型偶尔带前后缀)
  3. 仍失败 → 用相同 prompt 重试 1 次
  4. 再失败 → 安全降级:
       ask  → {verdict:"irrelevant", comment:"我没太懂,换个问法?"}
       guess→ {solved:false, comment:"还差点意思,再想想~"}
```
→ 保证 LLM 抽风时游戏不崩。

---

## 七、GameRunner 集成 Bridge

`haiguitang` 进入 GameRunner 后,需要在 WebView 上注册 Bridge。判定方式:manifest 的 game entry 增加可选 `capabilities: ["bridge"]`(或约定 `id == "haiguitang"`),命中则:

```swift
// makeWebView / viewDidLoad 中
let bridge = GameBridge(webView: webView)
bridge.register(handler: AIBridgeHandler())     // ai.* → HaiguitangService
config.userContentController.add(bridge, name: "WCGameBridge")
// 注入 bridge.js(随 bundle 自带,index.html <script> 引入即可,无需原生注入)
```

`GameBridge` 收到 message → 解析 `{callId, method, params}` → 按 `method` 前缀找 handler → `await handler.handle(...)` → `webView.evaluateJavaScript("window.WCGameBridge._resolve('\(callId)', \(json))")`。所有回调切回主线程执行 JS。

> 现有纯 web 游戏(2048 等)不注册 Bridge,行为不变;Bridge 仅对声明 `capabilities` 的游戏启用,向后兼容。

---

## 八、数据流

### 8.1 开局
```
进入 GameRunner(id=haiguitang)→ 加载 bundle → bridge.js 就绪
H5: WCGameBridge.call('ai.startPuzzle', {difficulty:'normal'})
  → GameBridge → AIBridgeHandler → HaiguitangService.startPuzzle
    → AIClient.complete(生成 prompt) → Claude → {title, surface, solution}
    → 存 session(含 solution)→ 回 {puzzleId, title, surface}
H5: 渲染汤面卡片,进入问答
```

### 8.2 提问
```
H5: 玩家输入"他认识凶手吗?" → WCGameBridge.call('ai.ask', {puzzleId, question})
  → HaiguitangService.ask:拼 (solution+surface+history+question) 判定 prompt
    → AIClient.complete(temp 0.2) → 解析 {verdict, comment, solved}
    → history 追加 (question, verdict) → 回 H5
H5: 追加一条答案气泡(verdict 文案 + comment);solved=true → 弹通关
```

### 8.3 解答 / 提示 / 放弃
```
guess  → 判定是否抓住真相 → solved 则回 solution、弹通关揭晓
hint   → 回一条提示文案,H5 加一条系统气泡
giveUp → 回 solution,H5 揭晓汤底、本局结束
```

---

## 九、Provider 配置与"蹭 Max"

| 场景 | Provider | baseURL | 鉴权 | 成本 |
|---|---|---|---|---|
| 单测 / CI | MockProvider | — | — | 0 |
| 本地开发 / 录屏演示 | ClaudeProvider | `http://localhost:PORT`(本地代理) | 代理侧用 Max 登录态 | 走 Max 额度 |
| 真机 / 上架演示 | ClaudeProvider | `https://api.anthropic.com` | Keychain 里的 API Key | 按 token(项目用量极小) |

**本地代理**(开发期):Mac 上跑一个小服务(Claude Agent SDK / Claude Code 驱动,复用 Max 登录态),暴露一个 Anthropic 兼容的 `/v1/messages`;iOS 模拟器请求 `localhost`。**仅用于开发/演示**,不作为线上架构(真机/上架走直连 + Keychain)。API Key 绝不进 bundle / JS / 源码。

---

## 十、错误处理

| 场景 | 行为 |
|---|---|
| 网络 / AI 失败 | Bridge 回 `{ok:false, error}` → H5 toast「AI 思考失败,点重试」 |
| LLM JSON 不合规 | 抽取子串 → 重试 1 次 → 安全降级 verdict(见 6.4) |
| 限流 429 | `AIError.rateLimited` → H5 提示「太快啦,缓一下」 + 退避 |
| Bridge 调用超时 | bridge.js 30s 超时 reject → H5 提示重试 |
| 汤底意外泄露风险 | 汤底只存原生;prompt 约束 comment 不剧透;guess/giveUp 才下发 |
| WebView 重载导致丢局 | session 存原生,puzzleId 不变可续局(Phase 3 可做断点续玩) |

---

## 十一、测试

复用现有 `XXXModuleTests` 风格,基于 **MockProvider** 全离线、零成本:

- **HaiguitangServiceTests**
  - 生成局:Mock 返回合法生成 JSON → session 正确建立、surface 下发、solution 不下发。
  - 裁判解析:各 verdict 正常解析;带历史的一致性。
  - 守卫降级:Mock 返回脏 JSON(带前后缀 / 纯乱码)→ 抽取成功 / 重试 / 最终安全降级。
  - 通关:guess 命中 → solved=true 且返回 solution。
- **GameBridgeTests**:`{callId, method, params}` 派发到正确 handler;未知 method → 错误回调;callId 正确配对。
- **AIKit**:ClaudeProvider 请求构造(header/body/baseURL 切换);MockProvider 路由。

---

## 十二、迭代路径

### Phase 1 — 端到端跑通一局(~1 周)
- AIKit:`AIProvider` / `AIRequest|Response` / `ClaudeProvider`(直连 + 本地代理 baseURL)/ `MockProvider` / `AIClient` / `AIConfig`。
- GameBridge:`WKScriptMessageHandler` + callId 回调 + handler 派发;`AIBridgeHandler`。
- HaiguitangService:`startPuzzle` / `ask` + 会话状态 + JSON 解析守卫 + 安全降级。
- haiguitang H5:index/bridge.js/main.js/style.css,汤面卡片 + 问答流 + 输入框(先只 ask)。
- GameRunner:按 `capabilities` 注册 Bridge。
- manifest 加 `haiguitang` 条目(capabilities:["bridge"]),打 zip 上 OSS。
- **验证**:大厅 → 海龟汤 → 生成汤面 → 连续提问拿到「是/不是/无关」。

### Phase 2 — 完整玩法 + 测试(~3-5 天)
- `guess` / `hint` / `giveUp` 全通;通关弹窗揭晓汤底。
- 难度 / 主题选择(开局面板)。
- "AI 思考中"动画、错误重试、超时提示。
- MockProvider + 单测(HaiguitangService / Bridge / AIKit)。
- **验证**:能完整玩通一局并通关 / 放弃;CI 全绿。

### Phase 3 — 打磨 / 加分项(~2-3 天)
- 汤面揭晓流式动画(可选,Bridge 加 `ai.askStream`)。
- Provider 切换入口(设置里:直连 / 代理 / Mock)。
- 断点续玩(puzzleId 续局)、本局历史回看。
- 本地代理脚本 + README + Demo 视频。

---

## 十三、风险与缓解

| 风险 | 缓解 |
|---|---|
| LLM 不输出合规 JSON | 严格 schema 指令 + 抽取子串 + 重试 + 安全降级(6.4) |
| 同一问题判定漂移 | temperature 0.2 + 历史进上下文,保持一致 |
| 汤底被玩家从前端扒出 | 汤底只存原生,JS/DevTools 拿不到;comment 禁剧透 |
| API Key 泄露 | Keychain 存储,不进 bundle / JS / git;直连才用,代理无需 key |
| API 成本 | Mock 测试 + 本地代理蹭 Max + 短 max_tokens(判定 ≤128) |
| Bridge 回调时序错乱 | callId 一一配对 + JS 侧 30s 超时 + 原生主线程执行回调 |
| 老游戏受 Bridge 影响 | Bridge 仅对 `capabilities:["bridge"]` 游戏启用,2048 等不变 |
| 生成的汤面质量参差 | system prompt 给优质范例 + 约束谜题可解性;难度参数引导 |

---

## 十四、面试话术(简历讲法)

> "在自研的小游戏框架上落地了一款生成式 AI 游戏『海龟汤』。先做了一个最小 JS Bridge,让 H5 小游戏能异步调用原生 AI 能力——`WCGameBridge.call(method, params)` 返回 Promise,原生侧 `WKScriptMessageHandler` 收消息、按命名空间派发、`evaluateJavaScript` 用 callId 回调,30s 超时兜底。原生这层抽了个可插拔的 AIKit:`AIProvider` 协议下挂 Claude 直连、本地代理、Mock 三种实现,运行时可切;Mock 让整局游戏能零成本跑单测和 CI。
>
> 游戏核心是把 LLM 约束成『裁判』:开局让 Claude 生成汤面 + 汤底,**汤底只留在原生层不下发**,既防作弊又保证后续判定带着真相做上下文、前后一致;每次问答要求模型严格输出 JSON,配解析守卫——抽子串、重试、再不行安全降级,保证模型抽风时游戏不崩。这套强调的是『搜索/规则该用算法,语言/创意才用 LLM』,以及怎么把不确定的 LLM 工程化成可靠产品。"
