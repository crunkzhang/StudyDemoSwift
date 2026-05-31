import UIKit
import ExtensionKit

/// 楼层型渲染:每个顶层 section 节点 = 一个「楼层」,用 CompositionalLayout 各自布局。
/// - banner / text → 1 个整宽 item
/// - grid → children 平铺成 N 列九宫格
/// - 未知 type → 空楼层(跳过,向前兼容)
public final class DSLCollectionController: NSObject {

    public let collectionView: UICollectionView
    private var floors: [DSLNode] = []
    private var context = DSLContext()

    public init(frame: CGRect = .zero) {
        let layout = UICollectionViewCompositionalLayout { _, _ in nil }
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        super.init()
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(DSLBannerCell.self, forCellWithReuseIdentifier: DSLBannerCell.reuseId)
        collectionView.register(DSLGridCell.self, forCellWithReuseIdentifier: DSLGridCell.reuseId)
        collectionView.register(DSLTextCell.self, forCellWithReuseIdentifier: DSLTextCell.reuseId)
    }

    public func render(_ page: DSLPage, injected: [String: DSLValue] = [:]) {
        context = DSLContext(pageData: page.data, injected: injected)
        if let bg = page.background { collectionView.backgroundColor = UIColor(hex: bg) }
        // 只保留已知楼层(未知跳过)
        floors = page.sections.filter { DSLComponentRegistry.shared.isKnown($0.type) }
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        collectionView.reloadData()
    }

    // MARK: - 布局

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] index, _ in
            guard let self, index < self.floors.count else { return nil }
            switch self.floors[index].type {
            case "banner": return self.bannerSection()
            case "grid":   return self.gridSection(columns: self.floors[index].int("columns") ?? 4)
            case "text":   return self.textSection()
            default:       return self.emptySection()
            }
        }
    }

    private func bannerSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(112))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 12, leading: 12, bottom: 4, trailing: 12)
        return section
    }

    private func gridSection(columns: Int) -> NSCollectionLayoutSection {
        let cols = max(1, columns)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(cols)), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(88)),
            subitem: item, count: cols)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 6
        section.contentInsets = .init(top: 6, leading: 8, bottom: 10, trailing: 8)
        return section
    }

    private func textSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(56))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 8, leading: 18, bottom: 0, trailing: 18)
        return section
    }

    private func emptySection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(0.1))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }

    private func node(at indexPath: IndexPath) -> DSLNode {
        let floor = floors[indexPath.section]
        if floor.type == "grid" { return (floor.children ?? [])[indexPath.item] }
        return floor
    }
}

extension DSLCollectionController: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int { floors.count }

    public func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let floor = floors[section]
        if floor.type == "grid" { return (floor.children ?? []).count }
        return floor.type == "spacer" ? 0 : 1
    }

    public func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let floor = floors[indexPath.section]
        switch floor.type {
        case "banner":
            let c = cv.dequeueReusableCell(withReuseIdentifier: DSLBannerCell.reuseId, for: indexPath) as! DSLBannerCell
            c.configure(floor, context); return c
        case "grid":
            let c = cv.dequeueReusableCell(withReuseIdentifier: DSLGridCell.reuseId, for: indexPath) as! DSLGridCell
            c.configure((floor.children ?? [])[indexPath.item], context); return c
        case "text":
            let c = cv.dequeueReusableCell(withReuseIdentifier: DSLTextCell.reuseId, for: indexPath) as! DSLTextCell
            c.configure(floor, context); return c
        default:
            return UICollectionViewCell()
        }
    }
}

extension DSLCollectionController: UICollectionViewDelegate {
    public func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        DSLAction.handle(node(at: indexPath).action)
    }
}
