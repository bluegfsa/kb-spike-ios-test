import UIKit

/// 设置面板拨钮开关（纯黑白灰，不用蓝）：开＝黑底白钮在右、关＝灰轮廓钮在左；点按滑动切换。
final class SettingsToggleControl: UIControl {
    private let trackView = UIView()
    private let knobView = UIView()
    private var knobCenterX: NSLayoutConstraint!

    private let trackW: CGFloat = 46
    private let trackH: CGFloat = 26
    private let knobD: CGFloat = 20

    /// 开/关状态；改变时更新外观并做滑动过渡。
    var isOn: Bool = true { didSet { apply(animated: true) } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: trackW + 12, height: max(44, trackH + 12)) } // 触控热区高≥44

    private func setup() {
        trackView.translatesAutoresizingMaskIntoConstraints = false
        trackView.isUserInteractionEnabled = false
        trackView.layer.cornerRadius = trackH / 2
        addSubview(trackView)

        knobView.translatesAutoresizingMaskIntoConstraints = false
        knobView.isUserInteractionEnabled = false
        knobView.layer.cornerRadius = knobD / 2
        addSubview(knobView)

        knobCenterX = knobView.centerXAnchor.constraint(equalTo: trackView.centerXAnchor, constant: 0)
        NSLayoutConstraint.activate([
            trackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.widthAnchor.constraint(equalToConstant: trackW),
            trackView.heightAnchor.constraint(equalToConstant: trackH),
            knobView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            knobView.widthAnchor.constraint(equalToConstant: knobD),
            knobView.heightAnchor.constraint(equalToConstant: knobD),
            knobCenterX,
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        apply(animated: false)
    }

    private func apply(animated: Bool) {
        let onColor = UIColor.label
        let offColor = UIColor.systemGray
        trackView.backgroundColor = isOn ? onColor : .clear
        trackView.layer.borderColor = (isOn ? onColor : offColor).cgColor
        trackView.layer.borderWidth = isOn ? 0 : 2
        knobView.backgroundColor = isOn ? UIColor.systemBackground : offColor
        knobCenterX.constant = isOn ? (trackW - trackH) / 2 : -(trackW - trackH) / 2
        accessibilityValue = isOn ? "开" : "关"
        if animated {
            UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) { self.layoutIfNeeded() }
        } else {
            layoutIfNeeded()
        }
    }

    @objc private func tapped() {
        isOn.toggle()
        sendActions(for: .valueChanged)
    }
}
