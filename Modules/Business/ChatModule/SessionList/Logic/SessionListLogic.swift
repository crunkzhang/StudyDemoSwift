import Foundation
import Combine
import WCIMSDK

/// 会话列表业务逻辑层 — 协调 DBHandler / DBObserver / SortRuleChain。
/// 对 VC 暴露:@Published sessions(变更流)+ triggerRemoteSync(async 命令)。
public final class SessionListLogic {

    @Published public private(set) var sessions: [SessionCellModel] = []

    private let handler: SessionDBHandler
    private let sortChain: SortRuleChain
    private var cancellable: AnyCancellable?

    /// P0:依赖注入 — 测试时可传 mock SessionDB,默认走 WCIMSDK 实例。
    public init(db: SessionDB? = WCIMSDK.sessionDB,
                sortChain: SortRuleChain = .default) {
        guard let db = db else {
            fatalError("SessionListLogic 初始化时 SessionDB 为 nil — 请先 WCIMSDK.setup")
        }
        self.handler = SessionDBHandler(db: db)
        self.sortChain = sortChain
    }

    public func start() {
        loadAndSort()
        // P0:直接订阅 DBChangeStream,删除 SessionDBObserver 中转层
        cancellable = DBChangeStream.shared.sessionsPublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                self?.handleChange(event)
            }
    }

    /// VC viewDidAppear / Sync 按钮 触发增量同步。
    /// - Parameter force: 手动按钮传 true(Mock 才吐新增量);viewDidAppear 传 false。
    public func triggerRemoteSync(force: Bool = false) async {
        await WCIMSDK.syncCoordinator?.triggerSync(force: force)
    }

    #if DEBUG
    /// 强制从 DB 全量重读 — 仅 DEBUG 配合 🗑️ 清库,生产不需要。
    public func reloadFromDB() {
        loadAndSort()
    }
    #endif

    // MARK: - Private

    private func handleChange(_ event: SessionChangeEvent) {
        // P0:统一走 loadAndSort — delete 也重排,避免未来新增 SortRule 后忘同步
        switch event {
        case .insert, .update, .delete:
            loadAndSort()
        }
    }

    private func loadAndSort() {
        let all = handler.fetchAll()
        let sorted = sortChain.sort(all)
        DispatchQueue.main.async { [weak self] in self?.sessions = sorted }
    }
}

// MARK: - 默认排序链

public extension SortRuleChain {
    /// 默认链:置顶 → 草稿 → 时间倒序。
    /// UnreadFirstSortRule 按业务方需求可选开启,这里不放进默认。
    /// P1:static let 缓存,避免每次访问重新构造 chain + rule 实例。
    static let `default` = SortRuleChain(rules: [
        PinnedSortRule(),
        DraftSortRule(),
        TimestampSortRule(),
    ])
}
