import UIKit
import SnapKit
import ExtensionKit

/// 可组合卡片:card 节点的 children 是一组「积木」,纵向堆叠成不同布局。
/// 积木类型:header / amount / rows(+row)/ link / divider / footer
/// 不同卡片用不同积木组合 → 订单卡 / 支付卡 / 链接卡 视觉各异。
/// 未知积木类型自动跳过(向前兼容)。
public final class DSLCardView: UIView {

    public var onTap: (() -> Void)?
    private let action: String?
    private let ctx: DSLContext

    public init(node: DSLNode, context: DSLContext = DSLContext()) {
        self.action = node.action
        self.ctx = context
        super.init(frame: .zero)
        backgroundColor = .white
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor(hex: "#ECECEC").cgColor
        build(node)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(_ node: DSLNode) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let blocks = node.children ?? [node]   // 无 children 时把自己当 header(兼容旧格式)
        for block in blocks {
            if let v = makeBlock(block) { stack.addArrangedSubview(v) }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func handleTap() { onTap?(); DSLAction.handle(action) }

    // MARK: - 积木工厂

    private func makeBlock(_ n: DSLNode) -> UIView? {
        switch n.type {
        case "header", "card": return headerBlock(n)
        case "amount":         return amountBlock(n)
        case "rows":           return rowsBlock(n)
        case "link":           return linkBlock(n)
        case "divider":        return dividerBlock()
        case "footer":         return footerBlock(n)
        default:               return nil   // 未知积木跳过
        }
    }

    private func text(_ n: DSLNode, _ key: String) -> String? { DSLTemplate.resolve(n.string(key), ctx) }

    /// header:圆角图标 + 标题 + 副标题
    private func headerBlock(_ n: DSLNode) -> UIView {
        let v = UIView()
        let color = UIColor(hex: n.string("thumbColor") ?? "#07C160")
        let wrap = UIView()
        wrap.backgroundColor = color.withAlphaComponent(0.12)
        wrap.layer.cornerRadius = 10; wrap.layer.cornerCurve = .continuous
        let icon = UIImageView(image: UIImage(systemName: n.string("thumb") ?? "doc.text.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        icon.tintColor = color
        let title = label(text(n, "title"), 16, .semibold, "#1A1A1A", lines: 2)
        let sub = label(text(n, "subtitle"), 13, .regular, "#8A9099", lines: 2)
        v.addSubview(wrap); wrap.addSubview(icon); v.addSubview(title); v.addSubview(sub)
        wrap.snp.makeConstraints { m in m.leading.equalToSuperview().offset(14); m.top.equalToSuperview().offset(14); m.width.height.equalTo(42); m.bottom.lessThanOrEqualToSuperview().offset(-14) }
        icon.snp.makeConstraints { $0.center.equalToSuperview() }
        title.snp.makeConstraints { m in m.leading.equalTo(wrap.snp.trailing).offset(12); m.top.equalTo(wrap); m.trailing.equalToSuperview().offset(-14) }
        sub.snp.makeConstraints { m in m.leading.trailing.equalTo(title); m.top.equalTo(title.snp.bottom).offset(4); m.bottom.lessThanOrEqualToSuperview().offset(-14) }
        return v
    }

    /// amount:大金额 + 说明(支付卡风格)
    private func amountBlock(_ n: DSLNode) -> UIView {
        let v = UIView()
        let amount = label(text(n, "amount"), 30, .bold, n.string("color") ?? "#1A1A1A")
        let caption = label(text(n, "caption"), 14, .regular, "#8A9099", lines: 2)
        v.addSubview(amount); v.addSubview(caption)
        amount.snp.makeConstraints { m in m.leading.equalToSuperview().offset(16); m.trailing.lessThanOrEqualToSuperview().offset(-16); m.top.equalToSuperview().offset(18) }
        caption.snp.makeConstraints { m in m.leading.equalTo(amount); m.trailing.equalToSuperview().offset(-16); m.top.equalTo(amount.snp.bottom).offset(6); m.bottom.equalToSuperview().offset(-16) }
        return v
    }

    /// rows:键值列表(订单卡风格)
    private func rowsBlock(_ n: DSLNode) -> UIView {
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 8
        let container = UIView(); container.addSubview(stack)
        stack.snp.makeConstraints { m in m.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)) }
        for row in (n.children ?? []) where row.type == "row" {
            let line = UIView()
            let k = label(text(row, "label"), 14, .regular, "#8A9099")
            let val = label(text(row, "value"), 14, .medium, "#333333"); val.textAlignment = .right
            line.addSubview(k); line.addSubview(val)
            k.snp.makeConstraints { m in m.leading.top.bottom.equalToSuperview() }
            val.snp.makeConstraints { m in m.trailing.top.bottom.equalToSuperview(); m.leading.greaterThanOrEqualTo(k.snp.trailing).offset(8) }
            stack.addArrangedSubview(line)
        }
        return container
    }

    /// link:左标题副标题 + 右侧缩略图(链接卡风格)
    private func linkBlock(_ n: DSLNode) -> UIView {
        let v = UIView()
        let title = label(text(n, "title"), 16, .semibold, "#1A1A1A", lines: 2)
        let sub = label(text(n, "subtitle"), 13, .regular, "#8A9099", lines: 2)
        let color = UIColor(hex: n.string("thumbColor") ?? "#576B95")
        let thumb = UIView(); thumb.backgroundColor = color.withAlphaComponent(0.14)
        thumb.layer.cornerRadius = 8; thumb.layer.cornerCurve = .continuous
        let icon = UIImageView(image: UIImage(systemName: n.string("thumb") ?? "link")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)))
        icon.tintColor = color
        v.addSubview(thumb); thumb.addSubview(icon); v.addSubview(title); v.addSubview(sub)
        thumb.snp.makeConstraints { m in m.trailing.equalToSuperview().offset(-14); m.top.equalToSuperview().offset(14); m.width.height.equalTo(54); m.bottom.lessThanOrEqualToSuperview().offset(-14) }
        icon.snp.makeConstraints { $0.center.equalToSuperview() }
        title.snp.makeConstraints { m in m.leading.equalToSuperview().offset(14); m.top.equalTo(thumb); m.trailing.equalTo(thumb.snp.leading).offset(-12) }
        sub.snp.makeConstraints { m in m.leading.trailing.equalTo(title); m.top.equalTo(title.snp.bottom).offset(4); m.bottom.lessThanOrEqualToSuperview().offset(-14) }
        return v
    }

    private func dividerBlock() -> UIView {
        let v = UIView()
        let line = UIView(); line.backgroundColor = UIColor(hex: "#F0F0F0")
        v.addSubview(line)
        line.snp.makeConstraints { m in m.leading.equalToSuperview().offset(14); m.trailing.equalToSuperview().offset(-14); m.top.bottom.equalToSuperview(); m.height.equalTo(1) }
        return v
    }

    private func footerBlock(_ n: DSLNode) -> UIView {
        let v = UIView()
        let t = label(text(n, "text"), 12, .regular, "#9A9A9A")
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        arrow.tintColor = UIColor(hex: "#C7CBD2")
        v.addSubview(t); v.addSubview(arrow)
        t.snp.makeConstraints { m in m.leading.equalToSuperview().offset(14); m.top.equalToSuperview().offset(9); m.bottom.equalToSuperview().offset(-11) }
        arrow.snp.makeConstraints { m in m.trailing.equalToSuperview().offset(-14); m.centerY.equalTo(t) }
        return v
    }

    private func label(_ str: String?, _ size: CGFloat, _ weight: UIFont.Weight, _ hex: String, lines: Int = 1) -> UILabel {
        let l = UILabel()
        l.text = str
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = UIColor(hex: hex)
        l.numberOfLines = lines
        return l
    }
}
