import UIKit
import SnapKit
import DSLKit

/// DSL 卡片消息气泡:把 cardJSON 解析成 DSLNode → DSLCardView 嵌进气泡。
/// 高度走 cell 自适应(BaseMessageCell 链路 + automaticDimension)。
public final class CardMessageCell: BaseMessageCell {
    public static let reuseID = "CardMessageCell"

    private let cardWidth: CGFloat = 250
    private var cardView: DSLCardView?

    public func configure(_ m: MessageCellModel) {
        cardView?.removeFromSuperview()
        cardView = nil

        bubbleView.backgroundColor = .clear

        if let json = m.cardJSON,
           let data = json.data(using: .utf8),
           let node = try? JSONDecoder().decode(DSLNode.self, from: data) {
            let card = DSLCardView(node: node)
            bubbleView.addSubview(card)
            card.snp.makeConstraints { $0.edges.equalToSuperview() }
            cardView = card
        }

        bubbleView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.width.equalTo(cardWidth)
            if m.isFromMe {
                make.trailing.equalToSuperview().offset(-14)
            } else {
                make.leading.equalToSuperview().offset(14)
            }
        }

        statusIndicator.snp.remakeConstraints { make in
            make.centerY.equalTo(bubbleView)
            if m.isFromMe {
                make.trailing.equalTo(bubbleView.snp.leading).offset(-6)
            } else {
                make.leading.equalTo(bubbleView.snp.trailing).offset(6)
            }
            make.width.height.equalTo(20)
        }
        failedIcon.snp.remakeConstraints { make in
            make.center.equalTo(statusIndicator)
            make.width.height.equalTo(22)
        }

        applyStatus(m.status, isFromMe: m.isFromMe)
    }
}
