import Foundation

/// 通用 id-keyed diff — 找出新数组中"id 没变但内容变了"的索引,
/// 用于 reloadRows(at:)/reconfigureItems(_:) 增量刷新。
///
/// 用法:
/// ```
/// let changed = DiffHelper.changedIndices(
///     from: oldMessages, to: newMessages, keyedBy: \.localMsgId
/// )
/// tableView.reloadRows(at: changed.map { IndexPath(row: $0, section: 0) }, with: .none)
/// ```
enum DiffHelper {
    static func changedIndices<Item: Equatable, Key: Hashable>(
        from old: [Item],
        to new: [Item],
        keyedBy keyPath: KeyPath<Item, Key>
    ) -> [Int] {
        let oldByKey = Dictionary(uniqueKeysWithValues: old.map { ($0[keyPath: keyPath], $0) })
        return new.enumerated().compactMap { i, item in
            guard let oldItem = oldByKey[item[keyPath: keyPath]], oldItem != item else { return nil }
            return i
        }
    }
}
