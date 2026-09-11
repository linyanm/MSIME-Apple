import UIKit

final class KeyboardLayoutPickerView: UIView {
  init(selected: KeyboardLayoutPreset, nineKey: Bool, onSelect: @escaping (KeyboardLayoutPreset) -> Void, onClose: @escaping () -> Void) {
    super.init(frame: .zero); accessibilityIdentifier = "keyboardLayoutPicker"
    let skin = KeyboardSkinPreference.selected; backgroundColor = skin.background
    let title = UILabel(); title.text = "选择键盘布局"; title.font = .systemFont(ofSize: 17, weight: .semibold); title.textColor = skin.keyForeground
    let close = UIButton(type: .system); close.setImage(UIImage(systemName: "chevron.left"), for: .normal); close.tintColor = skin.accent; close.accessibilityIdentifier = "closeLayoutPicker"; close.accessibilityLabel = "返回键盘"; close.addAction(UIAction { _ in onClose() }, for: .primaryActionTriggered)
    let scroll = UIScrollView(); scroll.alwaysBounceVertical = false
    let rows = UIStackView(); rows.axis = .vertical; rows.spacing = 12
    for index in stride(from: 0, to: KeyboardLayoutPreset.allCases.count, by: 2) {
      let row = UIStackView(); row.spacing = 12; row.distribution = .fillEqually
      for layout in KeyboardLayoutPreset.allCases[index..<min(index + 2, KeyboardLayoutPreset.allCases.count)] {
        let card = KeyboardKeyButton(); card.accessibilityIdentifier = "layoutCard-\(layout.rawValue)"; card.accessibilityLabel = layout.title; card.accessibilityValue = layout == selected ? "已选中" : ""; if layout == selected { card.accessibilityTraits.insert(.selected) }; card.backgroundColor = skin.keyBackground; card.layer.cornerRadius = 14; card.layer.borderWidth = layout == selected ? 2 : 1; card.layer.borderColor = (layout == selected ? skin.accent : UIColor.separator).cgColor
        let label = UILabel(); label.text = layout.title + (layout == selected ? "  ✓" : ""); label.font = .systemFont(ofSize: 14, weight: .semibold); label.textColor = skin.keyForeground
        let preview = KeyboardSkinMiniature(skin: skin, nineKey: nineKey)
        for item in [label, preview] { item.translatesAutoresizingMaskIntoConstraints = false; item.isUserInteractionEnabled = false; card.addSubview(item) }
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10), label.topAnchor.constraint(equalTo: card.topAnchor, constant: 10), label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8), preview.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8), preview.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8), preview.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8), preview.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8), preview.heightAnchor.constraint(equalTo: preview.widthAnchor, multiplier: KeyboardSkinMiniature.heightToWidthRatio)])
        card.addAction(UIAction { _ in onSelect(layout) }, for: .primaryActionTriggered); row.addArrangedSubview(card)
      }
      if row.arrangedSubviews.count == 1 { row.addArrangedSubview(UIView()) }; rows.addArrangedSubview(row)
    }
    for item in [title, close, scroll] { item.translatesAutoresizingMaskIntoConstraints = false; addSubview(item) }; rows.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(rows)
    NSLayoutConstraint.activate([close.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), close.topAnchor.constraint(equalTo: topAnchor), close.widthAnchor.constraint(equalToConstant: 44), close.heightAnchor.constraint(equalToConstant: 44), title.centerXAnchor.constraint(equalTo: centerXAnchor), title.centerYAnchor.constraint(equalTo: close.centerYAnchor), scroll.topAnchor.constraint(equalTo: close.bottomAnchor), scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), scroll.bottomAnchor.constraint(equalTo: bottomAnchor), rows.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12), rows.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12), rows.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), rows.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), rows.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
