import UIKit

/// 键盘顶部 44pt 功能条（第5版·单行横滑）：
/// · 空态：左 ⚙ 圆钮 ＋ 右 ↓ 圆钮；
/// · 输入态：上行拼音串；下行候选用**横向 UICollectionView 单行**（cell 只放 UILabel，不用 UIButton），
///   滚动/点选都交给 collection 原生仲裁，天生不抢首触；松手由 decelerationRate 惯性减速。
final class KeyboardTopBar: UIView {
    static let height: CGFloat = 44

    var onSettings: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onCandidate: ((Int) -> Void)?

    private let settingsButton = UIButton(type: .system)
    private let dismissCircleButton = UIButton(type: .system)
    private let dismissArrowButton = UIButton(type: .system)
    private let separatorView = UIView()
    private let pinyinLabel = UILabel()

    private lazy var flowLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .horizontal
        l.minimumLineSpacing = 16
        l.minimumInteritemSpacing = 16
        l.sectionInset = UIEdgeInsets(top: 1, left: 0, bottom: 1, right: 8)
        return l
    }()
    private lazy var candidateCollection: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        cv.alwaysBounceHorizontal = true
        cv.delaysContentTouches = false          // 首触立即进入滚动判定，不等 tap 失败
        cv.canCancelContentTouches = true        // 拖动时取消点选 → 横滑不误选
        cv.decelerationRate = .normal            // 松手按 velocity 自然减速（微信式惯性）
        cv.panGestureRecognizer.delaysTouchesBegan = false // 首触即接管
        cv.dataSource = self
        cv.delegate = self
        cv.register(CandidateCell.self, forCellWithReuseIdentifier: "Cand")
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private var items: [(text: String, translation: String?)] = []
    private var highlightFirst = true
    private var selectableNow = true
    private var pinyinTrailing: NSLayoutConstraint!
    private var collectionTrailing: NSLayoutConstraint!

    /// 输入态右侧整块宽（箭头热区等）。
    private let inputRightBlock: CGFloat = 68.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupMiddle()
        setupControls()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 圆钮 / 箭头
    private func styleCircle(_ btn: UIButton, symbol: String, pointSize: CGFloat, label: String) {
        btn.backgroundColor = KBColor.letterKey
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.isUserInteractionEnabled = true
        btn.accessibilityLabel = label
        btn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(btn)
        addCenteredImage(to: btn, symbol: symbol, pointSize: pointSize, weight: .regular, opticalY: 0)
    }

    private func addCenteredImage(to button: UIButton, symbol: String, pointSize: CGFloat, weight: UIImage.SymbolWeight, opticalY: CGFloat) {
        button.setImage(nil, for: .normal)
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let iv = UIImageView(image: UIImage(systemName: symbol, withConfiguration: cfg))
        iv.tintColor = KBColor.pinyin
        iv.contentMode = .center
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: opticalY),
        ])
    }

    private func setupControls() {
        styleCircle(settingsButton, symbol: "gearshape", pointSize: 15, label: "设置")
        styleCircle(dismissCircleButton, symbol: "chevron.down", pointSize: 13, label: "收起键盘")
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        dismissCircleButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissArrowButton.backgroundColor = .clear
        dismissArrowButton.isUserInteractionEnabled = true
        dismissArrowButton.accessibilityLabel = "收起键盘"
        dismissArrowButton.translatesAutoresizingMaskIntoConstraints = false
        dismissArrowButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        addSubview(dismissArrowButton)
        addCenteredImage(to: dismissArrowButton, symbol: "chevron.down", pointSize: 13, weight: .medium, opticalY: 0)
        separatorView.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 235/255, green: 235/255, blue: 245/255, alpha: 0.30)
                : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.25)
        }
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)
        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            dismissCircleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissCircleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissCircleButton.widthAnchor.constraint(equalToConstant: 32),
            dismissCircleButton.heightAnchor.constraint(equalToConstant: 32),
            dismissArrowButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissArrowButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissArrowButton.widthAnchor.constraint(equalToConstant: 44),
            dismissArrowButton.heightAnchor.constraint(equalToConstant: 44),
            separatorView.trailingAnchor.constraint(equalTo: dismissArrowButton.leadingAnchor, constant: -6),
            separatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 0.5),
            separatorView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    // MARK: - 中间：拼音串 + 候选单行 collection
    private func setupMiddle() {
        pinyinLabel.font = .systemFont(ofSize: 12)
        pinyinLabel.textColor = KBColor.pinyin
        pinyinLabel.lineBreakMode = .byTruncatingTail
        pinyinLabel.isUserInteractionEnabled = false // 不吃手势，触点到下面 collection
        pinyinLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pinyinLabel)

        addSubview(candidateCollection)

        pinyinTrailing = pinyinLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inputRightBlock)
        collectionTrailing = candidateCollection.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inputRightBlock)
        NSLayoutConstraint.activate([
            pinyinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pinyinTrailing,
            pinyinLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pinyinLabel.heightAnchor.constraint(equalToConstant: 14),
            candidateCollection.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            collectionTrailing,
            candidateCollection.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            candidateCollection.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    /// 刷新拼音串/候选。空态显圆钮；输入态显裸箭头＋分隔线、隐 ⚙。
    func update(buffer: String, candidates: [String], translations: [String?], selectable: Bool) {
        let typing = !(buffer.isEmpty && candidates.isEmpty)
        let hasCandidates = !candidates.isEmpty
        settingsButton.isHidden = typing
        dismissCircleButton.isHidden = typing
        // ⑤ 候选条「有内容」即隐藏收起键盘按钮（中英两态）；旧逻辑只看 candidates 为空会漏判英文态。
        let hasBarContent = hasCandidates || !buffer.isEmpty
            || translations.contains(where: { !($0 ?? "").isEmpty })
        let showDismiss = typing && !hasBarContent
        dismissArrowButton.isHidden = !showDismiss
        separatorView.isHidden = !showDismiss
        let trailingInset: CGFloat = hasCandidates ? -8 : -inputRightBlock
        pinyinTrailing.constant = trailingInset
        collectionTrailing.constant = trailingInset

        pinyinLabel.text = buffer
        pinyinLabel.isHidden = buffer.isEmpty

        items = candidates.enumerated().map { (i, t) in
            (t, i < translations.count ? translations[i] : nil)
        }
        highlightFirst = selectable
        selectableNow = selectable
        candidateCollection.isHidden = candidates.isEmpty
        candidateCollection.reloadData()
        candidateCollection.collectionViewLayout.invalidateLayout()
        candidateCollection.layoutIfNeeded()
        // 首帧 contentSize 可能为 0 → 下一帧再校正一次，保证首滑就有可滚范围
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.candidateCollection.layoutIfNeeded()
            self.candidateCollection.collectionViewLayout.invalidateLayout()
        }
    }

    private func itemWidth(text: String, translation: String?) -> CGFloat {
        let tw = (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 19)]).width
        var total = tw
        if let tr = translation, !tr.isEmpty {
            let trw = (tr as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width
            total += 4 + trw
        }
        return max(10, total)
    }

    @objc private func settingsTapped() { onSettings?() }
    @objc private func dismissTapped() { onDismiss?() }
}

// MARK: - 候选 cell（只放 UILabel，不用 UIButton → 不抢首触）
private final class CandidateCell: UICollectionViewCell {
    static let reuseID = "Cand"
    private let hanzi = UILabel()
    private let trans = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        hanzi.setContentHuggingPriority(.required, for: .horizontal)
        trans.font = .systemFont(ofSize: 11)
        trans.textColor = KBColor.translation
        trans.setContentHuggingPriority(.required, for: .horizontal)
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, translation: String?, highlight: Bool) {
        if highlight {
            let attr = NSMutableAttributedString(string: text)
            attr.addAttributes([
                .font: UIFont.systemFont(ofSize: 19, weight: .bold),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: KBColor.candidateText,
            ], range: NSRange(location: 0, length: attr.length))
            hanzi.attributedText = attr
        } else {
            hanzi.attributedText = nil
            hanzi.text = text
            hanzi.font = .systemFont(ofSize: 19)
            hanzi.textColor = KBColor.candidateText
        }
        trans.isHidden = (translation ?? "").isEmpty
        trans.text = translation
        if stack.arrangedSubviews.count < 2 {
            stack.addArrangedSubview(hanzi)
            stack.addArrangedSubview(trans)
        }
    }
}

// MARK: - collection 数据源/代理
extension KeyboardTopBar: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CandidateCell.reuseID, for: indexPath) as! CandidateCell
        let item = items[indexPath.item]
        cell.configure(text: item.text, translation: item.translation, highlight: highlightFirst && indexPath.item == 0)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = items[indexPath.item]
        return CGSize(width: itemWidth(text: item.text, translation: item.translation), height: 26)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard selectableNow else { return }
        KeyFeedback.shared.play()
        onCandidate?(indexPath.item)
    }
}
