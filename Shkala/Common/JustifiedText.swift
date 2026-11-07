import SwiftUI
import UIKit

/// معادل Text(..., textAlign = TextAlign.Justify) اندروید: Text خود SwiftUI ترازبندی دوطرفه نداره،
/// پس از UILabel با NSParagraphStyle.justified استفاده می‌شه (راست‌به‌چپ، با همون فونت و ارتفاع خط)
struct JustifiedText: UIViewRepresentable {
    let text: String
    var size: CGFloat = 13
    var weight: ShkWeight = .normal
    var lineHeight: CGFloat? = nil
    var color: Color = .primary

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributed()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fit.height))
    }

    private func attributed() -> NSAttributedString {
        let font = ShkFont.uiYekan(size, weight)
        let style = NSMutableParagraphStyle()
        style.alignment = .justified
        style.baseWritingDirection = .rightToLeft
        if let lineHeight {
            style.minimumLineHeight = lineHeight
            style.maximumLineHeight = lineHeight
        }
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: style,
            .foregroundColor: UIColor(color),
            .baselineOffset: lineHeight.map { max(0, ($0 - font.lineHeight) / 4) } ?? 0,
        ])
    }
}
