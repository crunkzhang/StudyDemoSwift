import Foundation
import Combine
import WCIMSDK

/// 会话列表业务逻辑层 — 协调 DBHandler / DBObserver / SortRuleChain。
/// 对 VC 暴露:@Published sessions(变更流)+ triggerRemoteSync(async 命令)。
public final class SessionListLogic {

    @Published public private(set) var sessions: [SessionCellModel] = []

    private let handler: SessionDBHandler
    private let observer: SessionDBObserver
    private let sortChain: SortRuleChain
    private var cancellable: AnyCancellable?

    public init(sortChain: SortRuleChain = .default) {
        guard let db = WCIMSDK.sessionDB else {
            fatalError("WCIMSDK.setup(userId:) must be called before SessionListLogic.init")
        }
        self.handler = SessionDBHandler(db: db)
        self.observer = SessionDBObserver()
        self.sortChain = sortChain
    }

    public func start() {
        loadAndSort()
        observer.start()
        cancellable = observer.changeSubject
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                self?.handleChange(event)
            }
    }

    public func stop() {
        cancellable?.cancel()
        observer.stop()
    }

    /// VC viewDidAppear / Sync 按钮 触发增量同步
    public func triggerRemoteSync() async {
        await WCIMSDK.syncCoordinator?.triggerSync()
    }

    // MARK: - Private

    private func handleChange(_ event: SessionChangeEvent) {
        switch event {
        case .insert, .update:
            loadAndSort()
        case .delete(let ids):
            let set = Set(ids)
            let filtered = sessions.filter { !set.contains($0.sessionId) }
            DispatchQueue.main.async { [weak self] in self?.sessions = filtered }
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
    /// Phase 1 默认链:置顶优先 → 时间倒序兜底。
    /// Phase 3 会加入 DraftSortRule / UnreadFirstSortRule。
    static var `default`: SortRuleChain {
        SortRuleChain(rules: [
            PinnedSortRule(),
            TimestampSortRule(),
        ])
    }
}
