import UIKit

/// Animate the key itself without changing the stack view's layout or input timing.
final class KeyboardKeyButton: UIButton {
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      updatePressFeedback()
    }
  }

  private func updatePressFeedback() {
    let pressed = isHighlighted && isEnabled
    let target = pressed
      ? CGAffineTransform(translationX: 0, y: 1).scaledBy(x: 0.94, y: 0.94)
      : .identity
    guard !UIAccessibility.isReduceMotionEnabled, window != nil else {
      layer.removeAllAnimations()
      transform = .identity
      return
    }
    UIView.animate(
      withDuration: pressed ? 0.06 : 0.18,
      delay: 0,
      usingSpringWithDamping: pressed ? 1 : 0.72,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction, .beginFromCurrentState]
    ) {
      self.transform = target
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      layer.removeAllAnimations()
      transform = .identity
    }
  }

  override var isEnabled: Bool {
    didSet {
      if !isEnabled { updatePressFeedback() }
    }
  }
}

/// Candidate chips highlight immediately, but a drag still belongs to the strip.
final class CandidateScrollView: UIScrollView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    delaysContentTouches = false
    disableEdgeEffects()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    delaysContentTouches = false
    disableEdgeEffects()
  }

  /// 关闭 iOS 26 起默认开启的滚动边缘效果。
  ///
  /// The effect fades and blurs content towards a scroll view's edges. On a strip one row tall it
  /// reaches the candidates themselves: the top of every chip was softened into a smudge while the
  /// keys beside them, which are not inside a scroll view, stayed sharp. Sampling the pixels showed
  /// it plainly -- the bottom of a chip held its exact fill colour, the top was blended with its
  /// surroundings. The strip only ever scrolls sideways, so there is no vertical edge to hint at.
  private func disableEdgeEffects() {
    guard #available(iOS 26.0, *) else { return }
    topEdgeEffect.isHidden = true
    bottomEdgeEffect.isHidden = true
  }

  override func touchesShouldCancel(in view: UIView) -> Bool {
    if view is KeyboardKeyButton { return true }
    return super.touchesShouldCancel(in: view)
  }
}
