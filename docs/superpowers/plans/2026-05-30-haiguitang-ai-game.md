# 海龟汤 AI 小游戏(GameModule L2)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec(`docs/superpowers/specs/2026-05-30-haiguitang-ai-game-design.md`)—— 最小 JS Bridge + 可插拔 AIKit + 海龟汤会话服务 + haiguitang H5,让 H5 小游戏通过 Bridge 调用原生 Claude 能力玩一局生成式海龟汤。

**Architecture:** 新建 `WeChatKit/AIKit` Pod(可复用 AI 能力层,`AIProvider` 协议 + Claude/Mock 实现);在 `Business/GameModule` 加 `Bridge/`(最小 JS Bridge)与 `Haiguitang/`(会话状态机 + 生成式裁判);新建 `WeChatGames/haiguitang/` H5 bundle 跑在现有 GameRunner 里。汤底只存原生层,绝不下发。

**Tech Stack:** Swift 5、UIKit、WKWebView、Swift Concurrency、URLSession、CryptoKit(已用)、SnapKit、CocoaPods、HTML/CSS/JS。

> **实现说明(对 spec 的一处细化):** AIKit 内 `ClaudeProvider` 直接用 `URLSession` 调 Anthropic `/v1/messages`,**不**经 `WeChatNetAPI`(那层围绕 `APIResp` 外壳 + `APIService` host 枚举设计,不适合第三方原始响应)。这样 AIKit 自包含、依赖少、易测。可插拔性由 `AIProvider` 协议保证,与用哪个 HTTP 客户端无关。

---

## File Structure

```
WeChatSwift/Modules/
├── WeChatKit/AIKit/                              ← 新建 Pod  [P1]
│   ├── AIKit.podspec
│   ├── Models.swift              # AIMessage / AIRequest / AIResponse / AIError
│   ├── AIProvider.swift          # protocol AIProvider
│   ├── MockProvider.swift        # 预设响应,测试/离线
│   ├── ClaudeProvider.swift      # Anthropic /v1/messages,URLSession
│   ├── AIClient.swift            # 持有 provider,可切换,统一入口
│   ├── AIConfig.swift            # provider 选择 / baseURL / model / Keychain key
│   └── AIKitTests/
│       ├── MockProviderTests.swift
│       ├── ClaudeProviderTests.swift
│       └── AIClientTests.swift
│
└── Business/GameModule/
    ├── GameModule.podspec                         [修改:依赖 AIKit;测试源加新文件]
    ├── Bridge/
    │   ├── GameBridge.swift       # WKScriptMessageHandler + callId 回调 + 派发
    │   ├── GameBridgeHandler.swift# protocol + BridgeResult
    │   └── AIBridgeHandler.swift  # ai.* → HaiguitangService
    ├── Haiguitang/
    │   ├── PuzzleSession.swift     # 单局状态 + Verdict + 各 Result 结构
    │   ├── HaiguitangPrompts.swift # system / 生成 / 判定 prompt 模板
    │   └── HaiguitangService.swift # 会话状态机 + 解析守卫 + 降级
    ├── Runner/VC/GameRunnerViewController.swift   [修改:按 capabilities 注册 Bridge]
    ├── BundleManager/GameManifest.swift           [修改:GameEntry 加 capabilities?]
    └── GameModuleTests/
        ├── HaiguitangServiceTests.swift
        └── GameBridgeTests.swift

WeChatSwift/Podfile                                [修改:加 AIKit pod]

HelloRN/WeChatGames/haiguitang/                    ← 新建 H5 bundle  [P1]
├── index.html
├── bridge.js
├── main.js
├── style.css
├── icon.png
└── README.md
```

**测试命令统一格式**(沿用现有 plan 约定,`<Pod>-Unit-Tests` 为 pod test_spec 生成的 scheme):
```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AIKit-Unit-Tests/<TestClass> 2>&1 | tail -15
```
GameModule 的测试把 scheme 段换成 `GameModule-Unit-Tests`。

---

# Phase 1 — 端到端跑通一局

## Task 1: AIKit pod 骨架 + 数据模型

**Files:**
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/AIKit.podspec`
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/Models.swift`
- Test: `WeChatSwift/Modules/WeChatKit/AIKit/AIKitTests/ModelsTests.swift`(临时,验证编译;Task 2 起换真实测试)

- [ ] **Step 1: 写 podspec**

```ruby
# AIKit.podspec
Pod::Spec.new do |s|
  s.name             = 'AIKit'
  s.version          = '1.0.0'
  s.summary          = '可插拔 AI 能力层(Claude / Mock)'
  s.description      = 'AIProvider 协议 + ClaudeProvider(Anthropic Messages API)+ MockProvider。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '*.swift'
  s.exclude_files = 'AIKitTests/**/*'
  s.frameworks = 'Foundation'

  s.test_spec 'AIKitTests' do |ts|
    ts.source_files = 'AIKitTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
```

- [ ] **Step 2: 写模型**

```swift
// Models.swift
import Foundation

public enum AIRole: String, Codable {
    case user
    case assistant
}

public struct AIMessage: Equatable {
    public let role: AIRole
    public let content: String
    public init(role: AIRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIRequest {
    public var system: String
    public var messages: [AIMessage]
    public var maxTokens: Int
    public var temperature: Double
    public init(system: String, messages: [AIMessage], maxTokens: Int = 256, temperature: Double = 0.2) {
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

public struct AIResponse: Equatable {
    public let text: String
    public init(text: String) { self.text = text }
}

public enum AIError: Error, Equatable {
    case network(String)      // 用 String 便于 Equatable / 测试
    case rateLimited
    case decoding
    case provider(message: String)
}
```

- [ ] **Step 3: 写临时编译验证测试**

```swift
// AIKitTests/ModelsTests.swift
import XCTest
@testable import AIKit

final class ModelsTests: XCTestCase {
    func test_request_defaults() {
        let req = AIRequest(system: "s", messages: [AIMessage(role: .user, content: "hi")])
        XCTAssertEqual(req.maxTokens, 256)
        XCTAssertEqual(req.temperature, 0.2, accuracy: 0.0001)
        XCTAssertEqual(req.messages.first?.role, .user)
    }
}
```

- [ ] **Step 4: Podfile 加 AIKit,pod install**

在 `WeChatSwift/Podfile` 里(其他本地 pod 声明附近)新增:
```ruby
  pod 'AIKit', :path => 'Modules/WeChatKit/AIKit'
```
运行:
```bash
cd WeChatSwift && pod install 2>&1 | tail -15
```
Expected: `Installing AIKit` 出现,无报错。

- [ ] **Step 5: 跑测试验证通过**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AIKit-Unit-Tests/ModelsTests 2>&1 | tail -15
```
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add Modules/WeChatKit/AIKit Podfile Podfile.lock WeChatSwift.xcworkspace
git commit -m "feat(ai): AIKit pod 骨架 + 数据模型

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: AIProvider 协议 + MockProvider

**Files:**
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/AIProvider.swift`
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/MockProvider.swift`
- Test: `WeChatSwift/Modules/WeChatKit/AIKit/AIKitTests/MockProviderTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// AIKitTests/MockProviderTests.swift
import XCTest
@testable import AIKit

final class MockProviderTests: XCTestCase {
    func test_mock_returnsConfiguredText() async throws {
        let mock = MockProvider { req in
            .success(AIResponse(text: "echo:" + (req.messages.last?.content ?? "")))
        }
        let resp = try await mock.complete(AIRequest(system: "", messages: [AIMessage(role: .user, content: "ping")]))
        XCTAssertEqual(resp.text, "echo:ping")
    }

    func test_mock_throwsConfiguredError() async {
        let mock = MockProvider { _ in .failure(.rateLimited) }
        do {
            _ = try await mock.complete(AIRequest(system: "", messages: []))
            XCTFail("应抛错")
        } catch let e as AIError {
            XCTAssertEqual(e, .rateLimited)
        } catch { XCTFail("错误类型不对") }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AIKit-Unit-Tests/MockProviderTests 2>&1 | tail -15
```
Expected: 编译失败(`AIProvider` / `MockProvider` 未定义)。

- [ ] **Step 3: 写协议与实现**

```swift
// AIProvider.swift
import Foundation

public protocol AIProvider {
    func complete(_ request: AIRequest) async throws -> AIResponse
}
```

```swift
// MockProvider.swift
import Foundation

/// 预设响应,用于单测 / CI / 离线演示。零成本,不发网络。
public final class MockProvider: AIProvider {
    private let handler: (AIRequest) -> Result<AIResponse, AIError>

    public init(handler: @escaping (AIRequest) -> Result<AIResponse, AIError>) {
        self.handler = handler
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        switch handler(request) {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AIKit-Unit-Tests/MockProviderTests 2>&1 | tail -15
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/WeChatKit/AIKit
git commit -m "feat(ai): AIProvider 协议 + MockProvider

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: ClaudeProvider(Anthropic /v1/messages)

把"构造请求"和"解析响应"抽成可单测的纯函数,避免测试发真实网络。

**Files:**
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/ClaudeProvider.swift`
- Test: `WeChatSwift/Modules/WeChatKit/AIKit/AIKitTests/ClaudeProviderTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// AIKitTests/ClaudeProviderTests.swift
import XCTest
@testable import AIKit

final class ClaudeProviderTests: XCTestCase {
    let provider = ClaudeProvider(baseURL: URL(string: "https://api.anthropic.com")!,
                                  apiKey: "sk-test", model: "claude-opus-4-8")

    func test_makeRequest_setsHeadersAndBody() throws {
        let req = AIRequest(system: "你是裁判",
                            messages: [AIMessage(role: .user, content: "他死了吗?")],
                            maxTokens: 128, temperature: 0.2)
        let urlReq = try provider.makeURLRequest(req)
        XCTAssertEqual(urlReq.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(urlReq.httpMethod, "POST")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = try JSONSerialization.jsonObject(with: urlReq.httpBody ?? Data()) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "claude-opus-4-8")
        XCTAssertEqual(body["max_tokens"] as? Int, 128)
        XCTAssertEqual(body["system"] as? String, "你是裁判")
        let msgs = body["messages"] as! [[String: Any]]
        XCTAssertEqual(msgs.first?["role"] as? String, "user")
        XCTAssertEqual(msgs.first?["content"] as? String, "他死了吗?")
    }

    func test_parse_joinsTextBlocks() throws {
        let json = """
        {"content":[{"type":"text","text":"是。"},{"type":"text","text":"接近真相了"}]}
        """.data(using: .utf8)!
        let resp = try provider.parse(json)
        XCTAssertEqual(resp.text, "是。接近真相了")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run(同上格式,`-only-testing:AIKit-Unit-Tests/ClaudeProviderTests`)
Expected: 编译失败(`ClaudeProvider` 未定义)。

- [ ] **Step 3: 实现**

```swift
// ClaudeProvider.swift
import Foundation

public final class ClaudeProvider: AIProvider {
    private let baseURL: URL
    private let apiKey: String?
    private let model: String
    private let session: URLSession

    public init(baseURL: URL, apiKey: String?, model: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    // MARK: - 可测纯函数

    func makeURLRequest(_ request: AIRequest) throws -> URLRequest {
        var urlReq = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "content-type")
        urlReq.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if let key = apiKey { urlReq.setValue(key, forHTTPHeaderField: "x-api-key") }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "system": request.system,
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlReq
    }

    func parse(_ data: Data) throws -> AIResponse {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else {
            throw AIError.decoding
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        return AIResponse(text: text)
    }

    // MARK: - AIProvider

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let urlReq = try makeURLRequest(request)
        do {
            let (data, resp) = try await session.data(for: urlReq)
            if let http = resp as? HTTPURLResponse {
                if http.statusCode == 429 { throw AIError.rateLimited }
                guard (200..<300).contains(http.statusCode) else {
                    let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                    throw AIError.provider(message: msg)
                }
            }
            return try parse(data)
        } catch let e as AIError {
            throw e
        } catch {
            throw AIError.network(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:AIKit-Unit-Tests/ClaudeProviderTests`)
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/WeChatKit/AIKit
git commit -m "feat(ai): ClaudeProvider 调 Anthropic Messages API

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: AIClient + AIConfig(可切换 provider)

**Files:**
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/AIClient.swift`
- Create: `WeChatSwift/Modules/WeChatKit/AIKit/AIConfig.swift`
- Test: `WeChatSwift/Modules/WeChatKit/AIKit/AIKitTests/AIClientTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// AIKitTests/AIClientTests.swift
import XCTest
@testable import AIKit

final class AIClientTests: XCTestCase {
    func test_client_usesCurrentProvider_andCanSwitch() async throws {
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: "A")) })
        let r1 = try await client.complete(AIRequest(system: "", messages: []))
        XCTAssertEqual(r1.text, "A")

        client.setProvider(MockProvider { _ in .success(AIResponse(text: "B")) })
        let r2 = try await client.complete(AIRequest(system: "", messages: []))
        XCTAssertEqual(r2.text, "B")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:AIKit-Unit-Tests/AIClientTests`)
Expected: 编译失败(`AIClient` 未定义)。

- [ ] **Step 3: 实现**

```swift
// AIClient.swift
import Foundation

public final class AIClient {
    public static let shared = AIClient(provider: MockProvider { _ in
        .success(AIResponse(text: "{}"))   // 默认空 Mock,App 启动时由 AIConfig 替换
    })

    private var provider: AIProvider
    private let lock = NSLock()

    public init(provider: AIProvider) { self.provider = provider }

    public func setProvider(_ p: AIProvider) {
        lock.lock(); defer { lock.unlock() }
        provider = p
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        lock.lock(); let p = provider; lock.unlock()
        return try await p.complete(request)
    }
}
```

```swift
// AIConfig.swift
import Foundation

public enum AIProviderKind {
    case claudeDirect(apiKey: String)               // https://api.anthropic.com
    case claudeProxy(baseURL: URL)                  // 本地代理蹭 Max,无需 key
    case mock(AIProvider)
}

public enum AIConfig {
    public static let defaultModel = "claude-opus-4-8"

    /// App 启动时调用,按环境装配 AIClient.shared 的 provider。
    public static func install(_ kind: AIProviderKind) {
        let provider: AIProvider
        switch kind {
        case .claudeDirect(let key):
            provider = ClaudeProvider(baseURL: URL(string: "https://api.anthropic.com")!,
                                      apiKey: key, model: defaultModel)
        case .claudeProxy(let baseURL):
            provider = ClaudeProvider(baseURL: baseURL, apiKey: nil, model: defaultModel)
        case .mock(let p):
            provider = p
        }
        AIClient.shared.setProvider(provider)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:AIKit-Unit-Tests/AIClientTests`)
Expected: PASS。

- [ ] **Step 5: 删除临时 ModelsTests 中的占位(保留即可,无害);Commit**

```bash
git add Modules/WeChatKit/AIKit
git commit -m "feat(ai): AIClient 可切换 provider + AIConfig 装配

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: 海龟汤会话模型 + Prompt 模板

**Files:**
- Create: `WeChatSwift/Modules/Business/GameModule/Haiguitang/PuzzleSession.swift`
- Create: `WeChatSwift/Modules/Business/GameModule/Haiguitang/HaiguitangPrompts.swift`
- (无独立测试,类型会被 Task 6/7 的测试覆盖)

- [ ] **Step 1: 写会话模型与结果类型**

```swift
// PuzzleSession.swift
import Foundation

public enum Verdict: String {
    case yes, no, irrelevant, partial, close
}

struct PuzzleSession {
    let puzzleId: String
    let title: String
    let surface: String          // 汤面(可下发)
    let solution: String         // 汤底(机密,绝不下发,除非 solved/giveUp)
    var history: [(question: String, verdict: Verdict)]
    var solved: Bool
    let difficulty: String
    let theme: String?
}

// 各动作返回(供 AIBridgeHandler 打包成 JSON)
struct StartResult { let puzzleId: String; let title: String; let surface: String }
struct AskResult   { let verdict: Verdict; let comment: String; let solved: Bool }
struct GuessResult { let solved: Bool; let comment: String; let solution: String? }
struct HintResult  { let hint: String }
struct GiveUpResult { let solution: String }
```

- [ ] **Step 2: 写 Prompt 模板**

```swift
// HaiguitangPrompts.swift
import Foundation

enum HaiguitangPrompts {

    static let generateSystem = """
    你是「海龟汤」情景推理游戏的出题人。海龟汤是一种猜谜:给玩家一段看似诡异、信息不全的「汤面」,
    隐藏一个能自洽解释一切的完整真相「汤底」。请生成一道**逻辑自洽、有唯一核心真相、可通过是非提问还原**的题目。
    只输出 JSON,不要任何多余文字,格式:
    {"title":"≤10字标题","surface":"2-4句汤面,只给现象不给原因","solution":"完整真相,解释汤面所有疑点"}
    """

    static func generateUser(difficulty: String, theme: String?) -> String {
        var s = "难度:\(difficulty)。"
        if let t = theme, !t.isEmpty { s += "主题:\(t)。" }
        s += "请出一道新题。"
        return s
    }

    static let judgeSystem = """
    你是「海龟汤」游戏的裁判。我会给你【汤面】【汤底(真相,仅你可见,严禁泄露)】和玩家的提问历史。
    针对玩家**本次是非提问**,只依据汤底判定,输出 JSON,不要多余文字:
    {"verdict":"yes|no|irrelevant|partial|close","comment":"≤15字、不得泄露汤底关键信息","solved":false}
    含义:yes=是 / no=不是 / irrelevant=与真相无关 / partial=部分正确(是也不是) / close=已非常接近真相。
    solved 恒为 false(是否通关由"解答"判定)。
    """

    static let guessSystem = """
    你是「海龟汤」裁判。玩家提交了他对真相的"还原"。请对照【汤底】判断他是否**抓住了核心真相**
    (细节不必完全一致,关键因果对上即可)。只输出 JSON:
    {"solved":true/false,"comment":"≤20字点评,不剧透"}
    """

    static let hintSystem = """
    你是「海龟汤」裁判。请基于【汤底】给玩家一条**不直接说破**的提示,引导其往关键方向想。
    只输出 JSON:{"hint":"≤25字提示"}
    """

    /// 把汤面 + 汤底 + 历史拼成判定用的 user 文本
    static func contextBlock(surface: String, solution: String,
                             history: [(question: String, verdict: Verdict)]) -> String {
        var s = "【汤面】\n\(surface)\n\n【汤底】\n\(solution)\n"
        if !history.isEmpty {
            s += "\n【已问历史】\n"
            for (i, h) in history.enumerated() {
                s += "\(i + 1). 问:\(h.question) 答:\(h.verdict.rawValue)\n"
            }
        }
        return s
    }
}
```

- [ ] **Step 3: GameModule.podspec 测试源已含 `GameModuleTests/**/*.swift`,无需改;编译确认**

```bash
cd WeChatSwift && pod install 2>&1 | tail -5
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED。

- [ ] **Step 4: Commit**

```bash
git add Modules/Business/GameModule/Haiguitang
git commit -m "feat(haiguitang): 会话模型 + prompt 模板

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: HaiguitangService.startPuzzle(生成关卡)

**Files:**
- Create: `WeChatSwift/Modules/Business/GameModule/Haiguitang/HaiguitangService.swift`
- Test: `WeChatSwift/Modules/Business/GameModule/GameModuleTests/HaiguitangServiceTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// GameModuleTests/HaiguitangServiceTests.swift
import XCTest
import AIKit
@testable import GameModule

final class HaiguitangServiceTests: XCTestCase {

    private func service(_ text: String) -> HaiguitangService {
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: text)) })
        return HaiguitangService(client: client)
    }

    func test_startPuzzle_buildsSessionAndHidesSolution() async throws {
        let svc = service(#"{"title":"海龟汤","surface":"他喝了汤就自杀了","solution":"那不是海龟汤"}"#)
        let r = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        XCTAssertEqual(r.title, "海龟汤")
        XCTAssertEqual(r.surface, "他喝了汤就自杀了")
        XCTAssertFalse(r.puzzleId.isEmpty)
        // 汤底不在返回里(StartResult 无 solution 字段),但 session 应已存
        XCTAssertNotNil(await svc.debugSolution(for: r.puzzleId))
        XCTAssertEqual(await svc.debugSolution(for: r.puzzleId), "那不是海龟汤")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/HaiguitangServiceTests`)
Expected: 编译失败(`HaiguitangService` 未定义)。

- [ ] **Step 3: 实现 startPuzzle + JSON 解析守卫**

```swift
// HaiguitangService.swift
import Foundation
import AIKit

public actor HaiguitangService {
    private let client: AIClient
    private var sessions: [String: PuzzleSession] = [:]

    public init(client: AIClient = .shared) { self.client = client }

    // 测试辅助:读某局汤底
    func debugSolution(for id: String) -> String? { sessions[id]?.solution }

    // MARK: - 生成

    func startPuzzle(difficulty: String, theme: String?) async throws -> StartResult {
        let req = AIRequest(
            system: HaiguitangPrompts.generateSystem,
            messages: [AIMessage(role: .user, content: HaiguitangPrompts.generateUser(difficulty: difficulty, theme: theme))],
            maxTokens: 512, temperature: 0.8
        )
        let resp = try await client.complete(req)
        guard let obj = Self.extractJSON(resp.text),
              let title = obj["title"] as? String,
              let surface = obj["surface"] as? String,
              let solution = obj["solution"] as? String else {
            throw AIError.decoding
        }
        let id = UUID().uuidString
        sessions[id] = PuzzleSession(puzzleId: id, title: title, surface: surface,
                                     solution: solution, history: [], solved: false,
                                     difficulty: difficulty, theme: theme)
        return StartResult(puzzleId: id, title: title, surface: surface)
    }

    // MARK: - JSON 守卫

    /// 直接解析失败时,抽取首个 {...} 子串再试。返回顶层字典或 nil。
    static func extractJSON(_ text: String) -> [String: Any]? {
        if let d = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            return obj
        }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        let sub = String(text[start...end])
        guard let d = sub.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return obj
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/HaiguitangServiceTests`)
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule/Haiguitang Modules/Business/GameModule/GameModuleTests
git commit -m "feat(haiguitang): startPuzzle 生成关卡 + JSON 解析守卫

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: HaiguitangService.ask(裁判 + 历史 + 降级)

**Files:**
- Modify: `WeChatSwift/Modules/Business/GameModule/Haiguitang/HaiguitangService.swift`
- Modify(加测试): `WeChatSwift/Modules/Business/GameModule/GameModuleTests/HaiguitangServiceTests.swift`

- [ ] **Step 1: 追加失败测试**

在 `HaiguitangServiceTests` 里加(可用一个会按"第N次调用"返回不同文本的 mock):

```swift
    // 顺序返回多段文本的 service:第1段给 startPuzzle,后续给 ask
    private func sequencedService(_ texts: [String]) -> HaiguitangService {
        let box = Box(texts)
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: box.next())) })
        return HaiguitangService(client: client)
    }

    func test_ask_parsesVerdict_andAppendsHistory() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相"}"#,
            #"{"verdict":"yes","comment":"没错","solved":false}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let ask = try await svc.ask(puzzleId: start.puzzleId, question: "他认识凶手吗?")
        XCTAssertEqual(ask.verdict, .yes)
        XCTAssertEqual(ask.comment, "没错")
        XCTAssertFalse(ask.solved)
        XCTAssertEqual(await svc.debugHistoryCount(for: start.puzzleId), 1)
    }

    func test_ask_malformedJSON_fallsBackSafely() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相"}"#,
            "嗯……这个嘛(模型抽风,非 JSON)"
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let ask = try await svc.ask(puzzleId: start.puzzleId, question: "?")
        XCTAssertEqual(ask.verdict, .irrelevant)   // 安全降级
        XCTAssertFalse(ask.comment.isEmpty)
    }

    func test_ask_unknownPuzzle_throws() async {
        let svc = service("{}")
        do { _ = try await svc.ask(puzzleId: "nope", question: "?"); XCTFail() }
        catch {}
    }
}

// 测试用的小工具:线程安全顺序取值
final class Box {
    private var items: [String]; private let lock = NSLock()
    init(_ items: [String]) { self.items = items }
    func next() -> String { lock.lock(); defer { lock.unlock() }
        return items.isEmpty ? "{}" : items.removeFirst() }
}
```

> 注:测试里调用了 `debugHistoryCount`,需在 service 加该辅助方法(下一步一并实现)。

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/HaiguitangServiceTests`)
Expected: 编译失败(`ask` / `debugHistoryCount` 未定义)。

- [ ] **Step 3: 实现 ask + 一次重试 + 安全降级**

在 `HaiguitangService` 里追加:

```swift
    func debugHistoryCount(for id: String) -> Int { sessions[id]?.history.count ?? 0 }

    func ask(puzzleId: String, question: String) async throws -> AskResult {
        guard var session = sessions[puzzleId] else { throw AIError.provider(message: "puzzle not found") }
        let ctx = HaiguitangPrompts.contextBlock(surface: session.surface,
                                                 solution: session.solution, history: session.history)
        let user = ctx + "\n【玩家本次提问】\n\(question)"
        let req = AIRequest(system: HaiguitangPrompts.judgeSystem,
                            messages: [AIMessage(role: .user, content: user)],
                            maxTokens: 128, temperature: 0.2)

        let parsed = await completeJSONWithRetry(req)
        let verdict = (parsed?["verdict"] as? String).flatMap(Verdict.init(rawValue:)) ?? .irrelevant
        let comment = (parsed?["comment"] as? String) ?? "我没太懂,换个问法?"
        let solved = (parsed?["solved"] as? Bool) ?? false

        session.history.append((question: question, verdict: verdict))
        if solved { session.solved = true }
        sessions[puzzleId] = session
        return AskResult(verdict: verdict, comment: comment, solved: solved)
    }

    /// 调一次,解析失败再重试一次;最终仍失败返回 nil(由调用方走安全降级默认值)。
    private func completeJSONWithRetry(_ req: AIRequest) async -> [String: Any]? {
        for _ in 0..<2 {
            if let resp = try? await client.complete(req),
               let obj = Self.extractJSON(resp.text) {
                return obj
            }
        }
        return nil
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/HaiguitangServiceTests`)
Expected: PASS(注意:`test_ask_malformedJSON` 因重试会消耗 2 段相同的脏文本——本测试 mock 对 ask 阶段始终返回脏文本,故重试两次都失败,正确降级。若 `sequencedService` 在第 2 段后耗尽返回 `"{}"`,`extractJSON` 会解析成功但无字段,仍走默认 `.irrelevant`,断言依旧成立。)

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule
git commit -m "feat(haiguitang): ask 裁判 + 历史上下文 + 重试与安全降级

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: GameBridge 协议 + AIBridgeHandler

先做 handler(纯逻辑,可测),Task 9 再做 WKWebView 绑定。

**Files:**
- Create: `WeChatSwift/Modules/Business/GameModule/Bridge/GameBridgeHandler.swift`
- Create: `WeChatSwift/Modules/Business/GameModule/Bridge/AIBridgeHandler.swift`
- Test: `WeChatSwift/Modules/Business/GameModule/GameModuleTests/GameBridgeTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// GameModuleTests/GameBridgeTests.swift
import XCTest
import AIKit
@testable import GameModule

final class GameBridgeTests: XCTestCase {

    private func handler(_ texts: [String]) -> AIBridgeHandler {
        let box = Box(texts)
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: box.next())) })
        return AIBridgeHandler(service: HaiguitangService(client: client))
    }

    func test_startPuzzle_returnsSurfaceNotSolution() async {
        let h = handler([#"{"title":"T","surface":"汤面X","solution":"汤底Y"}"#])
        let result = await h.handle(method: "ai.startPuzzle", params: ["difficulty": "normal"])
        guard case .success(let data) = result else { return XCTFail("应成功") }
        XCTAssertEqual(data["surface"] as? String, "汤面X")
        XCTAssertNotNil(data["puzzleId"])
        XCTAssertNil(data["solution"])           // 绝不下发汤底
    }

    func test_unknownMethod_returnsFailure() async {
        let h = handler(["{}"])
        let result = await h.handle(method: "ai.unknown", params: [:])
        guard case .failure(let code, _) = result else { return XCTFail("应失败") }
        XCTAssertEqual(code, "UNKNOWN_METHOD")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/GameBridgeTests`)
Expected: 编译失败。

- [ ] **Step 3: 实现协议 + AIBridgeHandler**

```swift
// GameBridgeHandler.swift
import Foundation

public enum BridgeResult {
    case success([String: Any])
    case failure(code: String, message: String)
}

public protocol GameBridgeHandler {
    /// 命名空间,如 "ai";GameBridge 按 method 的前缀("ai.ask" → "ai")派发
    var namespace: String { get }
    func handle(method: String, params: [String: Any]) async -> BridgeResult
}
```

```swift
// AIBridgeHandler.swift
import Foundation

public final class AIBridgeHandler: GameBridgeHandler {
    public let namespace = "ai"
    private let service: HaiguitangService

    public init(service: HaiguitangService = HaiguitangService()) {
        self.service = service
    }

    public func handle(method: String, params: [String: Any]) async -> BridgeResult {
        do {
            switch method {
            case "ai.startPuzzle":
                let r = try await service.startPuzzle(
                    difficulty: params["difficulty"] as? String ?? "normal",
                    theme: params["theme"] as? String)
                return .success(["puzzleId": r.puzzleId, "title": r.title, "surface": r.surface])

            case "ai.ask":
                guard let id = params["puzzleId"] as? String,
                      let q = params["question"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId/question")
                }
                let r = try await service.ask(puzzleId: id, question: q)
                return .success(["verdict": r.verdict.rawValue, "comment": r.comment, "solved": r.solved])

            default:
                return .failure(code: "UNKNOWN_METHOD", message: method)
            }
        } catch {
            return .failure(code: "AI_ERROR", message: "\(error)")
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/GameBridgeTests`)
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule/Bridge Modules/Business/GameModule/GameModuleTests
git commit -m "feat(bridge): GameBridgeHandler 协议 + AIBridgeHandler(start/ask)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: GameBridge(WKScriptMessageHandler + callId 回调)

**Files:**
- Create: `WeChatSwift/Modules/Business/GameModule/Bridge/GameBridge.swift`
- Modify(加测试): `WeChatSwift/Modules/Business/GameModule/GameModuleTests/GameBridgeTests.swift`

- [ ] **Step 1: 追加失败测试(测可派发的纯逻辑 `resolve`)**

```swift
    func test_bridge_dispatchesToRegisteredHandler() async {
        let h = handler([#"{"title":"T","surface":"汤面X","solution":"Y"}"#])
        let bridge = GameBridge()
        bridge.register(handler: h)
        let result = await bridge.resolve(method: "ai.startPuzzle", params: ["difficulty": "normal"])
        guard case .success(let data) = result else { return XCTFail() }
        XCTAssertEqual(data["surface"] as? String, "汤面X")
    }

    func test_bridge_noHandler_returnsFailure() async {
        let bridge = GameBridge()
        let result = await bridge.resolve(method: "im.share", params: [:])
        guard case .failure(let code, _) = result else { return XCTFail() }
        XCTAssertEqual(code, "NO_HANDLER")
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/GameBridgeTests`)
Expected: 编译失败(`GameBridge` 未定义)。

- [ ] **Step 3: 实现 GameBridge**

```swift
// GameBridge.swift
import Foundation
import WebKit

public final class GameBridge: NSObject, WKScriptMessageHandler {
    public static let messageHandlerName = "WCGameBridge"

    private weak var webView: WKWebView?
    private var handlers: [String: GameBridgeHandler] = [:]   // namespace -> handler

    public override init() { super.init() }
    public init(webView: WKWebView) { self.webView = webView; super.init() }

    public func attach(to webView: WKWebView) { self.webView = webView }

    public func register(handler: GameBridgeHandler) {
        handlers[handler.namespace] = handler
    }

    /// 可测的纯派发:按 method 前缀找 handler
    public func resolve(method: String, params: [String: Any]) async -> BridgeResult {
        let ns = method.split(separator: ".").first.map(String.init) ?? ""
        guard let handler = handlers[ns] else {
            return .failure(code: "NO_HANDLER", message: "no handler for \(ns)")
        }
        return await handler.handle(method: method, params: params)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let callId = body["callId"] as? String,
              let method = body["method"] as? String else { return }
        let params = body["params"] as? [String: Any] ?? [:]

        Task {
            let result = await resolve(method: method, params: params)
            await MainActor.run { self.callback(callId: callId, result: result) }
        }
    }

    private func callback(callId: String, result: BridgeResult) {
        let payload: [String: Any]
        switch result {
        case .success(let data):
            payload = ["ok": true, "data": data]
        case .failure(let code, let message):
            payload = ["ok": false, "error": ["code": code, "message": message]]
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: jsonData, encoding: .utf8) else { return }
        let js = "window.WCGameBridge && window.WCGameBridge._resolve('\(callId)', \(json));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/GameBridgeTests`)
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule/Bridge Modules/Business/GameModule/GameModuleTests
git commit -m "feat(bridge): GameBridge WKScriptMessageHandler + callId 回调

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: GameManifest 加 capabilities + GameRunner 注册 Bridge

**Files:**
- Modify: `WeChatSwift/Modules/Business/GameModule/BundleManager/GameManifest.swift`
- Modify: `WeChatSwift/Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift`
- Modify(加测试): `WeChatSwift/Modules/Business/GameModule/GameModuleTests/GameManifestTests.swift`

- [ ] **Step 1: 给 GameEntry 加可选 capabilities,补 decode 测试**

在 `GameManifestTests` 追加:
```swift
    func test_decode_capabilities() throws {
        let json = """
        { "manifestVersion":1,"updatedAt":"x","games":[{
          "id":"haiguitang","title":"海龟汤","icon":"x","version":"1.0",
          "url":"x","sha256":"x","size":1,"capabilities":["bridge"]
        }]}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(GameManifest.self, from: json)
        XCTAssertEqual(m.games[0].capabilities, ["bridge"])
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/GameManifestTests`)
Expected: 编译失败(`capabilities` 不存在)。

- [ ] **Step 3: 给 `GameEntry` 加字段**

在 `GameManifest.swift` 的 `GameEntry` 结构体里、`grayscale` 字段附近加:
```swift
    public let capabilities: [String]?   // 如 ["bridge"];nil 表示纯 web 游戏
```
(Codable 自动支持可选字段,缺省解析为 nil。)

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/GameManifestTests`)
Expected: PASS。

- [ ] **Step 5: GameRunner 按 capabilities 注册 Bridge**

在 `GameRunnerViewController.viewDidLoad` 里、`Task { await loadGame() }` 之前插入:
```swift
        // L2:声明 bridge 能力的游戏,注册 JS Bridge 调用原生 AI
        let game = GameBundleManager.shared.currentManifest?.games.first { $0.id == gameId }
        if game?.capabilities?.contains("bridge") == true {
            let bridge = GameBridge(webView: webView)
            bridge.register(handler: AIBridgeHandler())
            webView.configuration.userContentController.add(bridge, name: GameBridge.messageHandlerName)
            self.gameBridge = bridge   // 持有,避免被释放
        }
```
并在类里加存储属性:
```swift
    private var gameBridge: GameBridge?
```

- [ ] **Step 6: 编译确认**

```bash
cd WeChatSwift && pod install 2>&1 | tail -3
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED。

- [ ] **Step 7: GameModule.podspec 依赖 AIKit**

在 `GameModule.podspec` 的 `s.dependency` 列表加:
```ruby
  s.dependency 'AIKit'
```
重新 `pod install`,再 build 一次确认成功。

- [ ] **Step 8: Commit**

```bash
git add Modules/Business/GameModule
git commit -m "feat(game): GameEntry.capabilities + GameRunner 按需注册 Bridge

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: haiguitang H5 bundle(Phase 1:汤面 + 提问)

**Files:**
- Create: `HelloRN/WeChatGames/haiguitang/index.html`
- Create: `HelloRN/WeChatGames/haiguitang/bridge.js`
- Create: `HelloRN/WeChatGames/haiguitang/main.js`
- Create: `HelloRN/WeChatGames/haiguitang/style.css`
- Create: `HelloRN/WeChatGames/haiguitang/README.md`
- (icon.png:从现有任一游戏 icon 复制占位,或用纯色 png)

- [ ] **Step 1: index.html**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div id="surface" class="surface">正在出题…</div>
  <div id="feed" class="feed"></div>
  <div class="inputbar">
    <input id="q" type="text" placeholder="问一个是非题…" autocomplete="off"/>
    <button id="send">问</button>
  </div>
  <script src="bridge.js"></script>
  <script src="main.js"></script>
</body>
</html>
```

- [ ] **Step 2: bridge.js**(同 spec 4.2,逐字)

```js
(function () {
  const pending = {};
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

- [ ] **Step 3: main.js**(汤面 + 提问)

```js
const VERDICT_LABEL = {
  yes: "是", no: "不是", irrelevant: "无关", partial: "是也不是", close: "接近真相了"
};
let puzzleId = null;

const feed = document.getElementById('feed');
const surfaceEl = document.getElementById('surface');
const input = document.getElementById('q');
const sendBtn = document.getElementById('send');

function addBubble(text, cls) {
  const div = document.createElement('div');
  div.className = 'bubble ' + cls;
  div.textContent = text;
  feed.appendChild(div);
  feed.scrollTop = feed.scrollHeight;
}

async function start() {
  try {
    const data = await WCGameBridge.call('ai.startPuzzle', { difficulty: 'normal' });
    puzzleId = data.puzzleId;
    surfaceEl.textContent = '🐢 ' + data.title + '\n\n' + data.surface;
  } catch (e) {
    surfaceEl.textContent = '出题失败:' + (e.message || '未知错误');
  }
}

async function ask() {
  const q = input.value.trim();
  if (!q || !puzzleId) return;
  input.value = '';
  addBubble(q, 'me');
  addBubble('思考中…', 'ai thinking');
  const thinking = feed.lastChild;
  try {
    const data = await WCGameBridge.call('ai.ask', { puzzleId, question: q });
    thinking.remove();
    addBubble(VERDICT_LABEL[data.verdict] + (data.comment ? '——' + data.comment : ''), 'ai');
    if (data.solved) addBubble('🎉 你还原了真相!', 'system');
  } catch (e) {
    thinking.remove();
    addBubble('AI 思考失败,再试一次', 'system');
  }
}

sendBtn.onclick = ask;
input.addEventListener('keydown', e => { if (e.key === 'Enter') ask(); });
start();
```

- [ ] **Step 4: style.css**(微信风,简洁)

```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, sans-serif; background: #ededed; height: 100vh;
  display: flex; flex-direction: column; }
.surface { white-space: pre-wrap; background: #fff; margin: 12px; padding: 16px;
  border-radius: 12px; font-size: 16px; line-height: 1.6; color: #333; }
.feed { flex: 1; overflow-y: auto; padding: 0 12px 12px; }
.bubble { max-width: 78%; padding: 10px 14px; border-radius: 10px; margin: 6px 0;
  font-size: 15px; line-height: 1.4; word-break: break-word; }
.bubble.me { background: #95ec69; margin-left: auto; }
.bubble.ai { background: #fff; }
.bubble.ai.thinking { opacity: .5; }
.bubble.system { background: transparent; color: #999; text-align: center;
  margin: 8px auto; font-size: 13px; }
.inputbar { display: flex; gap: 8px; padding: 8px 12px; background: #f7f7f7;
  border-top: 1px solid #ddd; }
.inputbar input { flex: 1; border: none; border-radius: 8px; padding: 10px;
  font-size: 15px; }
.inputbar button { border: none; background: #07c160; color: #fff; border-radius: 8px;
  padding: 0 18px; font-size: 15px; }
```

- [ ] **Step 5: README.md**

```markdown
# 海龟汤(haiguitang)

情景推理 AI 小游戏。汤面/裁判由原生 Claude 生成,经 WCGameBridge 调用。

## 依赖
需宿主 App 支持 JS Bridge(GameModule L2),manifest 中本游戏 `capabilities:["bridge"]`。

## Bridge 协议
- ai.startPuzzle({difficulty}) -> {puzzleId,title,surface}
- ai.ask({puzzleId,question}) -> {verdict,comment,solved}
（Phase 2 增 guess/hint/giveUp）

## 打包
`cd WeChatGames && ./scripts/build.sh haiguitang 1.0`
```

- [ ] **Step 6: Commit**

```bash
cd /Users/carlos/HelloRN
git -C WeChatSwift add ../WeChatGames/haiguitang 2>/dev/null || true
# WeChatGames 若在 WeChatSwift 仓库外,则在其所属仓库提交;否则:
cd WeChatSwift && git add . && git commit -m "feat(haiguitang): H5 bundle Phase1 — 汤面 + 提问

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
> 注:`WeChatGames/` 位于 `HelloRN/` 顶层(非 git 仓库)。若它不在 `WeChatSwift` git 内,按现有 GameModule 工程约定处理(其 plan 已新建 `WeChatGames/`,沿用同一提交方式)。

---

## Task 12: 端到端联调(Mock provider 本地跑通)

无新文件;目标:不依赖真实 Claude,用 Mock 跑通"进游戏→出题→提问"。

- [ ] **Step 1: App 启动装配 Mock provider(临时联调)**

在 `AppDelegate` 启动流程里(GameModule 注册附近)加临时代码:
```swift
import AIKit
// 联调用:固定返回一局可玩的海龟汤
AIConfig.install(.mock(MockProvider { req in
    if req.system.contains("出题人") {
        return .success(AIResponse(text: #"{"title":"海龟汤","surface":"一个男人在餐厅点了海龟汤,喝一口后回家自杀了。","solution":"他曾遇海难,同伴用'海龟汤'之名喂他人肉求生;这次喝到真海龟汤,味道不同,他明白真相遂自杀。"}"#))
    }
    return .success(AIResponse(text: #"{"verdict":"no","comment":"再想想方向","solved":false}"#))
}))
```

- [ ] **Step 2: 把 haiguitang 加进本地 manifest / fallback bundle**

按现有 GameModule 的 fallback / 本地调试机制,把 `haiguitang` 放进可加载位置(参考 `GameBundleManager.fallbackBundleURL`),manifest 条目含 `"capabilities":["bridge"]`。具体放置方式follow现有 2048 等游戏的本地调试约定。

- [ ] **Step 3: 跑模拟器,手动验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```
然后在模拟器:发现 → 游戏 → 海龟汤。
Expected:
- 顶部显示汤面("一个男人在餐厅点了海龟汤…")
- 输入"他认识凶手吗?"→ 出现绿色我方气泡 + 白色 AI 气泡("不是——再想想方向")
- 连续提问正常追加

- [ ] **Step 4: 全量回归测试**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AIKit-Unit-Tests -only-testing:GameModule-Unit-Tests 2>&1 | tail -20
```
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
cd WeChatSwift && git add . && git commit -m "feat(haiguitang): Phase1 端到端联调(Mock)跑通

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# Phase 2 — 完整玩法 + 测试

## Task 13: HaiguitangService 加 guess / hint / giveUp

**Files:**
- Modify: `Haiguitang/HaiguitangService.swift`
- Modify(测试): `GameModuleTests/HaiguitangServiceTests.swift`

- [ ] **Step 1: 追加失败测试**

```swift
    func test_guess_solved_returnsSolution() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相Z"}"#,
            #"{"solved":true,"comment":"答对了"}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let g = try await svc.guess(puzzleId: start.puzzleId, guess: "我觉得是Z")
        XCTAssertTrue(g.solved)
        XCTAssertEqual(g.solution, "真相Z")     // 通关才下发汤底
    }

    func test_guess_notSolved_hidesSolution() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相Z"}"#,
            #"{"solved":false,"comment":"还差点"}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let g = try await svc.guess(puzzleId: start.puzzleId, guess: "瞎猜")
        XCTAssertFalse(g.solved)
        XCTAssertNil(g.solution)
    }

    func test_giveUp_returnsSolution() async throws {
        let svc = sequencedService([#"{"title":"T","surface":"S","solution":"真相Z"}"#])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let r = try await svc.giveUp(puzzleId: start.puzzleId)
        XCTAssertEqual(r.solution, "真相Z")
    }

    func test_hint_returnsText() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相Z"}"#,
            #"{"hint":"注意他的过去"}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let h = try await svc.hint(puzzleId: start.puzzleId)
        XCTAssertEqual(h.hint, "注意他的过去")
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/HaiguitangServiceTests`)
Expected: 编译失败(`guess`/`hint`/`giveUp` 未定义)。

- [ ] **Step 3: 实现**

在 `HaiguitangService` 追加:
```swift
    func guess(puzzleId: String, guess: String) async throws -> GuessResult {
        guard var session = sessions[puzzleId] else { throw AIError.provider(message: "not found") }
        let ctx = HaiguitangPrompts.contextBlock(surface: session.surface,
                                                 solution: session.solution, history: session.history)
        let user = ctx + "\n【玩家提交的还原】\n\(guess)"
        let req = AIRequest(system: HaiguitangPrompts.guessSystem,
                            messages: [AIMessage(role: .user, content: user)],
                            maxTokens: 128, temperature: 0.2)
        let parsed = await completeJSONWithRetry(req)
        let solved = (parsed?["solved"] as? Bool) ?? false
        let comment = (parsed?["comment"] as? String) ?? "还差点意思,再想想~"
        if solved { session.solved = true; sessions[puzzleId] = session }
        return GuessResult(solved: solved, comment: comment, solution: solved ? session.solution : nil)
    }

    func hint(puzzleId: String) async throws -> HintResult {
        guard let session = sessions[puzzleId] else { throw AIError.provider(message: "not found") }
        let ctx = HaiguitangPrompts.contextBlock(surface: session.surface,
                                                 solution: session.solution, history: session.history)
        let req = AIRequest(system: HaiguitangPrompts.hintSystem,
                            messages: [AIMessage(role: .user, content: ctx)],
                            maxTokens: 64, temperature: 0.5)
        let parsed = await completeJSONWithRetry(req)
        return HintResult(hint: (parsed?["hint"] as? String) ?? "再多问几个问题缩小范围吧")
    }

    func giveUp(puzzleId: String) throws -> GiveUpResult {
        guard let session = sessions[puzzleId] else { throw AIError.provider(message: "not found") }
        return GiveUpResult(solution: session.solution)
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/HaiguitangServiceTests`)
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule
git commit -m "feat(haiguitang): guess/hint/giveUp + 通关才下发汤底

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 14: AIBridgeHandler 扩展 guess / hint / giveUp

**Files:**
- Modify: `Bridge/AIBridgeHandler.swift`
- Modify(测试): `GameModuleTests/GameBridgeTests.swift`

- [ ] **Step 1: 追加失败测试**

```swift
    func test_giveUp_returnsSolution() async {
        let h = handler([#"{"title":"T","surface":"S","solution":"汤底Y"}"#])
        let start = await h.handle(method: "ai.startPuzzle", params: ["difficulty": "normal"])
        guard case .success(let s) = start, let id = s["puzzleId"] as? String else { return XCTFail() }
        let r = await h.handle(method: "ai.giveUp", params: ["puzzleId": id])
        guard case .success(let data) = r else { return XCTFail() }
        XCTAssertEqual(data["solution"] as? String, "汤底Y")
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run(`-only-testing:GameModule-Unit-Tests/GameBridgeTests`)
Expected: FAIL(giveUp 走到 default → UNKNOWN_METHOD)。

- [ ] **Step 3: 在 `AIBridgeHandler.handle` 的 switch 里、`default` 之前加 case**

```swift
            case "ai.guess":
                guard let id = params["puzzleId"] as? String,
                      let g = params["guess"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId/guess")
                }
                let r = try await service.guess(puzzleId: id, guess: g)
                var data: [String: Any] = ["solved": r.solved, "comment": r.comment]
                if let sol = r.solution { data["solution"] = sol }
                return .success(data)

            case "ai.hint":
                guard let id = params["puzzleId"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId")
                }
                let r = try await service.hint(puzzleId: id)
                return .success(["hint": r.hint])

            case "ai.giveUp":
                guard let id = params["puzzleId"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId")
                }
                let r = try await service.giveUp(puzzleId: id)
                return .success(["solution": r.solution])
```

- [ ] **Step 4: 跑测试确认通过**

Run(`-only-testing:GameModule-Unit-Tests/GameBridgeTests`)
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule
git commit -m "feat(bridge): AIBridgeHandler 支持 guess/hint/giveUp

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 15: H5 完整交互(提示 / 解答 / 放弃 / 通关弹窗 / 难度)

**Files:**
- Modify: `HelloRN/WeChatGames/haiguitang/index.html`
- Modify: `HelloRN/WeChatGames/haiguitang/main.js`
- Modify: `HelloRN/WeChatGames/haiguitang/style.css`

- [ ] **Step 1: index.html 加按钮栏与难度选择**

把 `.inputbar` 上方加一行操作条,并在 body 顶部加开局难度选择(简单做法:进入先弹三个难度按钮,选后调 start):
```html
  <div id="difficulty" class="difficulty">
    <p>选择难度</p>
    <button data-d="easy">简单</button>
    <button data-d="normal">普通</button>
    <button data-d="hard">困难</button>
  </div>
  <div class="actions">
    <button id="hintBtn">提示</button>
    <button id="guessBtn">我要解答</button>
    <button id="giveUpBtn">放弃</button>
  </div>
```

- [ ] **Step 2: main.js 增加对应逻辑**

把 `start()` 改为接收难度;新增 hint/guess/giveUp;通关/揭晓用一个简单弹窗:
```js
function showModal(title, body) {
  const m = document.createElement('div');
  m.className = 'modal';
  m.innerHTML = `<div class="modal-card"><h3>${title}</h3><p>${body}</p>
    <button onclick="this.closest('.modal').remove()">知道了</button></div>`;
  document.body.appendChild(m);
}

document.querySelectorAll('#difficulty button').forEach(btn => {
  btn.onclick = () => {
    document.getElementById('difficulty').style.display = 'none';
    start(btn.dataset.d);
  };
});

async function start(difficulty) {
  surfaceEl.textContent = '正在出题…';
  try {
    const data = await WCGameBridge.call('ai.startPuzzle', { difficulty });
    puzzleId = data.puzzleId;
    surfaceEl.textContent = '🐢 ' + data.title + '\n\n' + data.surface;
  } catch (e) { surfaceEl.textContent = '出题失败:' + (e.message || ''); }
}

document.getElementById('hintBtn').onclick = async () => {
  if (!puzzleId) return;
  try { const d = await WCGameBridge.call('ai.hint', { puzzleId });
    addBubble('💡 ' + d.hint, 'system'); } catch {}
};

document.getElementById('guessBtn').onclick = async () => {
  if (!puzzleId) return;
  const g = prompt('说说你还原的真相:');
  if (!g) return;
  addBubble('我的解答:' + g, 'me');
  try {
    const d = await WCGameBridge.call('ai.guess', { puzzleId, guess: g });
    if (d.solved) showModal('🎉 通关', '真相:' + d.solution);
    else addBubble('裁判:' + d.comment, 'ai');
  } catch { addBubble('判定失败,重试', 'system'); }
};

document.getElementById('giveUpBtn').onclick = async () => {
  if (!puzzleId) return;
  try { const d = await WCGameBridge.call('ai.giveUp', { puzzleId });
    showModal('汤底揭晓', d.solution); puzzleId = null; } catch {}
};
```
并删除原来文件末尾自动调用的 `start();`(改为难度选择后再调)。

- [ ] **Step 3: style.css 加 actions / difficulty / modal 样式**

```css
.difficulty { position: fixed; inset: 0; background: rgba(0,0,0,.5);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 12px; z-index: 10; color: #fff; }
.difficulty button { width: 160px; padding: 12px; border: none; border-radius: 8px;
  background: #07c160; color: #fff; font-size: 16px; }
.actions { display: flex; gap: 8px; padding: 6px 12px; background: #f7f7f7; }
.actions button { flex: 1; border: none; border-radius: 8px; padding: 8px;
  background: #fff; font-size: 14px; }
.modal { position: fixed; inset: 0; background: rgba(0,0,0,.5);
  display: flex; align-items: center; justify-content: center; z-index: 20; }
.modal-card { background: #fff; border-radius: 12px; padding: 20px; width: 80%;
  max-width: 320px; }
.modal-card h3 { margin-bottom: 10px; }
.modal-card p { line-height: 1.6; margin-bottom: 16px; white-space: pre-wrap; }
.modal-card button { width: 100%; border: none; background: #07c160; color: #fff;
  border-radius: 8px; padding: 10px; }
```

- [ ] **Step 4: 手动验证(Mock)**

build + 模拟器:选难度→出题→提问→提示→我要解答→通关弹窗;放弃→揭晓汤底。
(Mock 联调时让 guess 的 Mock 返回 `{"solved":true,...}` 验证通关路径。)

- [ ] **Step 5: Commit**

```bash
cd WeChatSwift && git add . && git commit -m "feat(haiguitang): H5 完整玩法 — 难度/提示/解答/放弃/通关弹窗

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 16: 真实 Claude 联调 + Provider 切换

**Files:**
- Modify: `WeChatSwift/WeChatSwift/AppDelegate.swift`

- [ ] **Step 1: 用环境装配真实 / 代理 provider**

把 Task 12 的临时 Mock 装配,改为按编译配置选择:
```swift
import AIKit
#if DEBUG
// 开发:本地代理蹭 Max(见 WeChatGames/haiguitang/README 的代理说明)。
// 模拟器访问宿主机用 localhost;真机改成 Mac 的局域网 IP。
AIConfig.install(.claudeProxy(baseURL: URL(string: "http://localhost:8787")!))
#else
AIConfig.install(.claudeDirect(apiKey: KeychainHelper.aiAPIKey() ?? ""))
#endif
```
> 若暂无本地代理,保留 `.mock(...)` 兜底;`KeychainHelper.aiAPIKey()` 按现有 Keychain 封装实现(无则先返回 nil,UI 报错可接受)。API Key 绝不硬编码进源码。

- [ ] **Step 2: 手动验证(若有代理 / API Key)**

build + 模拟器,完整玩一局真实生成的海龟汤。无代理/key 时本步骤可跳过,以 Mock 验证为准。

- [ ] **Step 3: Commit**

```bash
cd WeChatSwift && git add . && git commit -m "feat(ai): 按环境装配 provider(DEBUG 代理 / RELEASE 直连)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 17: 全量测试 + 打包上 OSS

- [ ] **Step 1: 全量单测**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AIKit-Unit-Tests -only-testing:GameModule-Unit-Tests 2>&1 | tail -25
```
Expected: 全部 PASS。

- [ ] **Step 2: 打 haiguitang zip 并上 OSS(沿用 GameModule 工作流)**

```bash
cd WeChatGames && ./scripts/build.sh haiguitang 1.0
# 输出 dist/haiguitang-v1.0.zip + SHA256
./scripts/upload.sh haiguitang 1.0    # 若已实现;否则手动传 OSS
```
然后编辑 OSS `games/manifest.json`,加 haiguitang 条目(含 `sha256` 与 `"capabilities":["bridge"]`)。

- [ ] **Step 3: 真机/模拟器走远程下发验证**

清掉本地缓存 → 进发现→游戏→大厅出现"海龟汤"卡片 → 点击自动下载 → 可玩。

- [ ] **Step 4: Commit(脚本 / manifest 片段若在仓库内)**

```bash
cd WeChatSwift && git add . && git commit -m "chore(haiguitang): 打包上线 v1.0 + manifest 接入

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# Phase 3 — 加分项(可选)

## Task 18(可选): 本地代理脚本 + 文档(蹭 Max)

**Files:**
- Create: `HelloRN/WeChatGames/haiguitang/proxy/README.md`
- Create: `HelloRN/WeChatGames/haiguitang/proxy/server.mjs`

- [ ] **Step 1: 写一个最小 Anthropic 兼容代理**(Node + Claude Agent SDK / 转发),监听 `localhost:8787`,把收到的 `/v1/messages` 请求用 Max 登录态转发给 Claude,返回 `{content:[{type:"text",text:...}]}` 形状。
- [ ] **Step 2: README 写清:仅开发/演示用;真机用局域网 IP;不可上架。**
- [ ] **Step 3: 启动代理 → DEBUG 跑 App → 玩一局真实海龟汤 → Commit。**

> 此任务依赖 Claude Agent SDK 的本地鉴权能力,实现细节以 SDK 当时文档为准;若不可行,退回 `.claudeDirect` + API Key 路线(成本极低)。

---

## Task 19(可选): 设置里切换 Provider

**Files:**
- Modify: MeModule 设置页(新增一项"AI 来源:代理/直连/Mock")
- 调 `AIConfig.install(...)` 运行时切换。

- [ ] 加一个简单 ActionSheet,三选一 → 调对应 `AIConfig.install`;选直连时弹输入框存 API Key 到 Keychain。Commit。

---

## Self-Review(已自检)

- **Spec 覆盖**:① 最小 JS Bridge → Task 8/9/10;② 可插拔 AIKit(Claude/代理/Mock)→ Task 1-4;③ HaiguitangService 生成+裁判+汤底不下发 → Task 6/7/13;④ 生成式无限关卡 → Task 6;⑤ 结构化输出 + 解析守卫/重试/降级 → Task 7;⑥ haiguitang H5 → Task 11/15;⑦ GameRunner 按 capabilities 集成 → Task 10;⑧ Mock 零成本测试 → Task 1-9/13/14;⑨ Provider 配置/蹭 Max → Task 16/18;⑩ 错误处理(超时/限流/降级)→ bridge.js 超时(Task 11)+ Task 3 限流 + Task 7 降级。全部有对应任务。
- **类型一致性**:`AIRequest/AIResponse/AIMessage/AIError/AIProvider`、`Verdict`、`StartResult/AskResult/GuessResult/HintResult/GiveUpResult`、`BridgeResult`、`GameBridge.resolve`、`HaiguitangService.{startPuzzle,ask,guess,hint,giveUp,completeJSONWithRetry,extractJSON}` 在定义与调用处命名一致。
- **占位符**:无 TBD/TODO;每个代码步骤均含完整代码。Phase 3 标注"可选"且依赖外部 SDK 处已写明回退路线。
- **已知前提**:`WeChatGames/` 的提交/打包沿用现有 GameModule plan 既定约定;`KeychainHelper` 若不存在,Task 16 已注明可先返回 nil。
