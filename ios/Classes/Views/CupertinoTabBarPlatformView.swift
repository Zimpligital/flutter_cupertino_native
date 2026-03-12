import Flutter
import UIKit

class CupertinoTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private var tabBar: UITabBar?
  private var tabBarLeft: UITabBar?
  private var tabBarRight: UITabBar?
  private var isSplit: Bool = false
  private var rightCountVal: Int = 1
  private var currentLabels: [String] = []
  private var currentActiveSymbols: [String] = []
  private var currentInactiveSymbols: [String] = []
  private var currentActiveColors: [NSNumber?] = []
  private var currentInactiveColors: [NSNumber?] = []
  private var currentActiveTextColors: [NSNumber?] = []
  private var currentInactiveTextColors: [NSNumber?] = []
  private var currentBadges: [Int?] = []
  private var currentSelectedIndex: Int = 0
  private var leftInsetVal: CGFloat = 0
  private var rightInsetVal: CGFloat = 0
  private var splitSpacingVal: CGFloat = 8
  private var blurOverlay: UIVisualEffectView?

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeTabBar_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)

    var labels: [String] = []
    var activeSymbols: [String] = []
    var inactiveSymbols: [String] = []
    var activeColors: [NSNumber?] = []
    var inactiveColors: [NSNumber?] = []
    var activeTextColors: [NSNumber?] = []
    var inactiveTextColors: [NSNumber?] = []
    var selectedIndex: Int = 0
    var isDark: Bool = false
    var tint: UIColor? = nil
    var bg: UIColor? = nil
    var split: Bool = false
    var rightCount: Int = 1
    var leftInset: CGFloat = 0
    var rightInset: CGFloat = 0
    var badges: [Int?] = []
    var blurred: Bool = false

    if let dict = args as? [String: Any] {
      labels = (dict["labels"] as? [String]) ?? []
      let fallbackSymbols = (dict["sfSymbols"] as? [String]) ?? []
      activeSymbols = (dict["activeSymbols"] as? [String]) ?? fallbackSymbols
      inactiveSymbols = (dict["inactiveSymbols"] as? [String]) ?? fallbackSymbols
      activeColors = (dict["activeColors"] as? [NSNumber?]) ?? []
      inactiveColors = (dict["inactiveColors"] as? [NSNumber?]) ?? []
      activeTextColors = (dict["activeTextColors"] as? [NSNumber?]) ?? []
      inactiveTextColors = (dict["inactiveTextColors"] as? [NSNumber?]) ?? []
      badges = (dict["badges"] as? [NSNumber?])?.map { $0?.intValue } ?? []
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["backgroundColor"] as? NSNumber { bg = Self.colorFromARGB(n.intValue) }
      }
      if let s = dict["split"] as? NSNumber { split = s.boolValue }
      if let rc = dict["rightCount"] as? NSNumber { rightCount = rc.intValue }
      if let sp = dict["splitSpacing"] as? NSNumber { splitSpacingVal = CGFloat(truncating: sp) }
      if let b = dict["blurred"] as? NSNumber { blurred = b.boolValue }
      // content insets controlled by Flutter padding; keep zero here
    }

    super.init()

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) { container.overrideUserInterfaceStyle = isDark ? .dark : .light }

    let appearance: UITabBarAppearance? = {
    if #available(iOS 13.0, *) { let ap = UITabBarAppearance(); ap.configureWithDefaultBackground(); return ap }
    return nil
  }()
    func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
      var items: [UITabBarItem] = []
      for i in range {
        let activeSym = i < activeSymbols.count ? activeSymbols[i] : ""
        let inactiveSym = i < inactiveSymbols.count ? inactiveSymbols[i] : ""
        var activeImage: UIImage? = activeSym.isEmpty ? nil : UIImage(systemName: activeSym)
        var inactiveImage: UIImage? = inactiveSym.isEmpty ? nil : UIImage(systemName: inactiveSym)
        if #available(iOS 13.0, *) {
          if let n = (i < activeColors.count ? activeColors[i] : nil) {
            activeImage = activeImage?.withTintColor(Self.colorFromARGB(n.intValue), renderingMode: .alwaysOriginal)
          }
          if let n = (i < inactiveColors.count ? inactiveColors[i] : nil) {
            inactiveImage = inactiveImage?.withTintColor(Self.colorFromARGB(n.intValue), renderingMode: .alwaysOriginal)
          }
        }
        let title = (i < labels.count) ? labels[i] : nil
        let item = UITabBarItem(title: title, image: inactiveImage, selectedImage: activeImage)
        if i < badges.count, let b = badges[i] { item.badgeValue = String(b) }
        items.append(item)
      }
      return items
    }
    let count = max(labels.count, max(activeSymbols.count, inactiveSymbols.count))
    if split && count > rightCount {
      let leftEnd = count - rightCount
      let left = UITabBar(frame: .zero)
      let right = UITabBar(frame: .zero)
      tabBarLeft = left; tabBarRight = right
      left.translatesAutoresizingMaskIntoConstraints = false
      right.translatesAutoresizingMaskIntoConstraints = false
      left.delegate = self; right.delegate = self
      if let bg = bg { left.barTintColor = bg; right.barTintColor = bg }
      if #available(iOS 10.0, *), let tint = tint { left.tintColor = tint; right.tintColor = tint }
      if let ap = appearance { if #available(iOS 13.0, *) { left.standardAppearance = ap; right.standardAppearance = ap } }
      left.items = buildItems(0..<leftEnd)
      right.items = buildItems(leftEnd..<count)
      if selectedIndex < leftEnd, let items = left.items {
        left.selectedItem = items[selectedIndex]
        right.selectedItem = nil
      } else if let items = right.items {
        let idx = selectedIndex - leftEnd
        if idx >= 0 && idx < items.count { right.selectedItem = items[idx] }
        left.selectedItem = nil
      }
      container.addSubview(left); container.addSubview(right)
      // Compute content-fitting widths for both bars and apply symmetric spacing
      let spacing: CGFloat = splitSpacingVal
      let leftWidth = left.sizeThatFits(.zero).width + leftInset * 2
      let rightWidth = right.sizeThatFits(.zero).width + rightInset * 2
      let total = leftWidth + rightWidth + spacing
      // If total exceeds container, fall back to proportional widths
      if total > container.bounds.width {
        let rightFraction = CGFloat(rightCount) / CGFloat(count)
        NSLayoutConstraint.activate([
          right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightInset),
          right.topAnchor.constraint(equalTo: container.topAnchor),
          right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          right.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: rightFraction),
          left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftInset),
          left.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -spacing),
          left.topAnchor.constraint(equalTo: container.topAnchor),
          left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
      } else {
        NSLayoutConstraint.activate([
          // Right bar fixed width, pinned to trailing
          right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightInset),
          right.topAnchor.constraint(equalTo: container.topAnchor),
          right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          right.widthAnchor.constraint(equalToConstant: rightWidth),
          // Left bar fixed width, pinned to leading
          left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftInset),
          left.topAnchor.constraint(equalTo: container.topAnchor),
          left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
          left.widthAnchor.constraint(equalToConstant: leftWidth),
          // Spacing between
          left.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -spacing),
        ])
      }
    } else {
      let bar = UITabBar(frame: .zero)
      tabBar = bar
      bar.delegate = self
      bar.translatesAutoresizingMaskIntoConstraints = false
      if let bg = bg { bar.barTintColor = bg }
      if #available(iOS 10.0, *), let tint = tint { bar.tintColor = tint }
      if let ap = appearance { if #available(iOS 13.0, *) { bar.standardAppearance = ap; if #available(iOS 15.0, *) { bar.scrollEdgeAppearance = ap } } }
      bar.items = buildItems(0..<count)
      if selectedIndex >= 0, let items = bar.items, selectedIndex < items.count { bar.selectedItem = items[selectedIndex] }
      container.addSubview(bar)
      NSLayoutConstraint.activate([
        bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        bar.topAnchor.constraint(equalTo: container.topAnchor),
        bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
    }
    // Store split settings for future updates
    self.isSplit = split
    self.rightCountVal = rightCount
    self.currentLabels = labels
    self.currentActiveSymbols = activeSymbols
    self.currentInactiveSymbols = inactiveSymbols
    self.currentActiveColors = activeColors
    self.currentInactiveColors = inactiveColors
    self.currentActiveTextColors = activeTextColors
    self.currentInactiveTextColors = inactiveTextColors
    self.currentBadges = badges
    self.currentSelectedIndex = selectedIndex
    self.leftInsetVal = leftInset
    self.rightInsetVal = rightInset
    applyLabelColors(selectedIndex: selectedIndex)
    if blurred { setBlurred(true) }
channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        if let bar = self.tabBar ?? self.tabBarLeft ?? self.tabBarRight {
          let size = bar.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
          result(["width": Double(size.width), "height": Double(size.height)])
        } else {
          result(["width": Double(self.container.bounds.width), "height": 50.0])
        }
      case "setItems":
        if let args = call.arguments as? [String: Any] {
          let labels = (args["labels"] as? [String]) ?? []
          let fallbackSymbols = (args["sfSymbols"] as? [String]) ?? []
          let activeSymbols = (args["activeSymbols"] as? [String]) ?? fallbackSymbols
          let inactiveSymbols = (args["inactiveSymbols"] as? [String]) ?? fallbackSymbols
          let activeColors = (args["activeColors"] as? [NSNumber?]) ?? []
          let inactiveColors = (args["inactiveColors"] as? [NSNumber?]) ?? []
          let activeTextColors = (args["activeTextColors"] as? [NSNumber?]) ?? []
          let inactiveTextColors = (args["inactiveTextColors"] as? [NSNumber?]) ?? []
          let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
          self.currentLabels = labels
          self.currentActiveSymbols = activeSymbols
          self.currentInactiveSymbols = inactiveSymbols
          self.currentActiveColors = activeColors
          self.currentInactiveColors = inactiveColors
          self.currentActiveTextColors = activeTextColors
          self.currentInactiveTextColors = inactiveTextColors
          let badges = self.currentBadges
          func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
            var items: [UITabBarItem] = []
            for i in range {
              let activeSym = i < activeSymbols.count ? activeSymbols[i] : ""
              let inactiveSym = i < inactiveSymbols.count ? inactiveSymbols[i] : ""
              var activeImage: UIImage? = activeSym.isEmpty ? nil : UIImage(systemName: activeSym)
              var inactiveImage: UIImage? = inactiveSym.isEmpty ? nil : UIImage(systemName: inactiveSym)
              if #available(iOS 13.0, *) {
                if let n = (i < activeColors.count ? activeColors[i] : nil) {
                  activeImage = activeImage?.withTintColor(Self.colorFromARGB(n.intValue), renderingMode: .alwaysOriginal)
                }
                if let n = (i < inactiveColors.count ? inactiveColors[i] : nil) {
                  inactiveImage = inactiveImage?.withTintColor(Self.colorFromARGB(n.intValue), renderingMode: .alwaysOriginal)
                }
              }
              let title = (i < labels.count) ? labels[i] : nil
              let item = UITabBarItem(title: title, image: inactiveImage, selectedImage: activeImage)
              if i < badges.count, let b = badges[i] { item.badgeValue = String(b) }
              items.append(item)
            }
            return items
          }
          let count = max(labels.count, max(activeSymbols.count, inactiveSymbols.count))
          if self.isSplit && count > self.rightCountVal, let left = self.tabBarLeft, let right = self.tabBarRight {
            let leftEnd = count - self.rightCountVal
            left.items = buildItems(0..<leftEnd)
            right.items = buildItems(leftEnd..<count)
            if selectedIndex < leftEnd, let items = left.items { left.selectedItem = items[selectedIndex]; right.selectedItem = nil }
            else if let items = right.items {
              let idx = selectedIndex - leftEnd
              if idx >= 0 && idx < items.count { right.selectedItem = items[idx]; left.selectedItem = nil }
            }
            self.currentSelectedIndex = selectedIndex
            self.applyLabelColors(selectedIndex: selectedIndex)
            result(nil)
          } else if let bar = self.tabBar {
            bar.items = buildItems(0..<count)
            if let items = bar.items, selectedIndex >= 0, selectedIndex < items.count { bar.selectedItem = items[selectedIndex] }
            self.currentSelectedIndex = selectedIndex
            self.applyLabelColors(selectedIndex: selectedIndex)
            result(nil)
          } else {
            result(FlutterError(code: "state_error", message: "Tab bars not initialized", details: nil))
          }
        } else { result(FlutterError(code: "bad_args", message: "Missing items", details: nil)) }
      case "setLayout":
        if let args = call.arguments as? [String: Any] {
          let split = (args["split"] as? NSNumber)?.boolValue ?? false
          let rightCount = (args["rightCount"] as? NSNumber)?.intValue ?? 1
          // Insets are controlled by Flutter padding; keep stored zeros here
          let leftInset = self.leftInsetVal
          let rightInset = self.rightInsetVal
          if let sp = args["splitSpacing"] as? NSNumber { self.splitSpacingVal = CGFloat(truncating: sp) }
          let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
          // Remove existing bars
          self.tabBar?.removeFromSuperview(); self.tabBar = nil
          self.tabBarLeft?.removeFromSuperview(); self.tabBarLeft = nil
          self.tabBarRight?.removeFromSuperview(); self.tabBarRight = nil
          let labels = self.currentLabels
          let activeSymbols = self.currentActiveSymbols
          let inactiveSymbols = self.currentInactiveSymbols
          let activeColors = self.currentActiveColors
          let inactiveColors = self.currentInactiveColors
          let badges = self.currentBadges
          let appearance: UITabBarAppearance? = {
            if #available(iOS 13.0, *) { let ap = UITabBarAppearance(); ap.configureWithDefaultBackground(); return ap }
            return nil
          }()
          func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
            var items: [UITabBarItem] = []
            for i in range {
              let activeSym = i < activeSymbols.count ? activeSymbols[i] : ""
              let inactiveSym = i < inactiveSymbols.count ? inactiveSymbols[i] : ""
              var activeImage: UIImage? = activeSym.isEmpty ? nil : UIImage(systemName: activeSym)
              var inactiveImage: UIImage? = inactiveSym.isEmpty ? nil : UIImage(systemName: inactiveSym)
              if #available(iOS 13.0, *) {
                if let n = (i < activeColors.count ? activeColors[i] : nil) {
                  activeImage = activeImage?.withTintColor(Self.colorFromARGB(n.intValue), renderingMode: .alwaysOriginal)
                }
                if let n = (i < inactiveColors.count ? inactiveColors[i] : nil) {
                  inactiveImage = inactiveImage?.withTintColor(Self.colorFromARGB(n.intValue), renderingMode: .alwaysOriginal)
                }
              }
              let title = (i < labels.count) ? labels[i] : nil
              let item = UITabBarItem(title: title, image: inactiveImage, selectedImage: activeImage)
              if i < badges.count, let b = badges[i] { item.badgeValue = String(b) }
              items.append(item)
            }
            return items
          }
          let count = max(labels.count, max(activeSymbols.count, inactiveSymbols.count))
          if split && count > rightCount {
            let leftEnd = count - rightCount
            let left = UITabBar(frame: .zero)
            let right = UITabBar(frame: .zero)
            self.tabBarLeft = left; self.tabBarRight = right
            left.translatesAutoresizingMaskIntoConstraints = false
            right.translatesAutoresizingMaskIntoConstraints = false
            left.delegate = self; right.delegate = self
            left.items = buildItems(0..<leftEnd)
            right.items = buildItems(leftEnd..<count)
            if selectedIndex < leftEnd, let items = left.items { left.selectedItem = items[selectedIndex]; right.selectedItem = nil }
            else if let items = right.items { let idx = selectedIndex - leftEnd; if idx >= 0 && idx < items.count { right.selectedItem = items[idx]; left.selectedItem = nil } }
            self.container.addSubview(left); self.container.addSubview(right)
            let spacing: CGFloat = splitSpacingVal
            let leftWidth = left.sizeThatFits(.zero).width + leftInset * 2
            let rightWidth = right.sizeThatFits(.zero).width + rightInset * 2
            let total = leftWidth + rightWidth + spacing
            if total > self.container.bounds.width {
              let rightFraction = CGFloat(rightCount) / CGFloat(count)
              NSLayoutConstraint.activate([
                right.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -rightInset),
                right.topAnchor.constraint(equalTo: self.container.topAnchor),
                right.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                right.widthAnchor.constraint(equalTo: self.container.widthAnchor, multiplier: rightFraction),
                left.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: leftInset),
                left.trailingAnchor.constraint(equalTo: right.leadingAnchor, constant: -spacing),
                left.topAnchor.constraint(equalTo: self.container.topAnchor),
                left.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
              ])
            } else {
              NSLayoutConstraint.activate([
                right.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -rightInset),
                right.topAnchor.constraint(equalTo: self.container.topAnchor),
                right.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                right.widthAnchor.constraint(equalToConstant: rightWidth),
                left.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: leftInset),
                left.topAnchor.constraint(equalTo: self.container.topAnchor),
                left.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                left.widthAnchor.constraint(equalToConstant: leftWidth),
                left.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -spacing),
              ])
            }
          } else {
            let bar = UITabBar(frame: .zero)
            self.tabBar = bar
            bar.delegate = self
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.items = buildItems(0..<count)
            if let items = bar.items, selectedIndex >= 0, selectedIndex < items.count { bar.selectedItem = items[selectedIndex] }
            self.container.addSubview(bar)
            NSLayoutConstraint.activate([
              bar.leadingAnchor.constraint(equalTo: self.container.leadingAnchor),
              bar.trailingAnchor.constraint(equalTo: self.container.trailingAnchor),
              bar.topAnchor.constraint(equalTo: self.container.topAnchor),
              bar.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
            ])
          }
          self.isSplit = split; self.rightCountVal = rightCount; self.leftInsetVal = leftInset; self.rightInsetVal = rightInset
          self.currentSelectedIndex = selectedIndex
          self.applyLabelColors(selectedIndex: selectedIndex)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing layout", details: nil)) }
      case "setSelectedIndex":
        if let args = call.arguments as? [String: Any], let idx = (args["index"] as? NSNumber)?.intValue {
          // Single bar
          if let bar = self.tabBar, let items = bar.items, idx >= 0, idx < items.count {
            bar.selectedItem = items[idx]
            self.currentSelectedIndex = idx
            self.applyLabelColors(selectedIndex: idx)
            result(nil)
            return
          }
          // Split bars
          if let left = self.tabBarLeft, let leftItems = left.items {
            if idx < leftItems.count, idx >= 0 {
              left.selectedItem = leftItems[idx]
              self.tabBarRight?.selectedItem = nil
              self.currentSelectedIndex = idx
              self.applyLabelColors(selectedIndex: idx)
              result(nil)
              return
            }
            if let right = self.tabBarRight, let rightItems = right.items {
              let ridx = idx - leftItems.count
              if ridx >= 0, ridx < rightItems.count {
                right.selectedItem = rightItems[ridx]
                self.tabBarLeft?.selectedItem = nil
                self.currentSelectedIndex = idx
                self.applyLabelColors(selectedIndex: idx)
                result(nil)
                return
              }
            }
          }
          result(FlutterError(code: "bad_args", message: "Index out of range", details: nil))
        } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["tint"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            if let bar = self.tabBar { bar.tintColor = c }
            if let left = self.tabBarLeft { left.tintColor = c }
            if let right = self.tabBarRight { right.tintColor = c }
          }
          if let n = args["backgroundColor"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            if let bar = self.tabBar { bar.barTintColor = c }
            if let left = self.tabBarLeft { left.barTintColor = c }
            if let right = self.tabBarRight { right.barTintColor = c }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) { self.container.overrideUserInterfaceStyle = isDark ? .dark : .light }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setBadges":
        if let args = call.arguments as? [String: Any] {
          let newBadges: [Int?] = (args["badges"] as? [NSNumber?])?.map { $0?.intValue } ?? []
          self.currentBadges = newBadges
          func applyBadge(to items: [UITabBarItem]?, offset: Int) {
            guard let items = items else { return }
            for (idx, item) in items.enumerated() {
              let i = idx + offset
              if i < newBadges.count, let b = newBadges[i] { item.badgeValue = String(b) }
              else { item.badgeValue = nil }
            }
          }
          applyBadge(to: self.tabBar?.items, offset: 0)
          let leftCount = self.tabBarLeft?.items?.count ?? 0
          applyBadge(to: self.tabBarLeft?.items, offset: 0)
          applyBadge(to: self.tabBarRight?.items, offset: leftCount)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing badges", details: nil)) }
      case "setBlur":
        if let args = call.arguments as? [String: Any],
           let b = (args["blurred"] as? NSNumber)?.boolValue {
          self.setBlurred(b); result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing blurred", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func setBlurred(_ blurred: Bool) {
    if blurred {
      guard blurOverlay == nil else { return }
      let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
      overlay.frame = container.bounds
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      container.addSubview(overlay)
      blurOverlay = overlay
    } else {
      blurOverlay?.removeFromSuperview()
      blurOverlay = nil
    }
  }

  private func applyLabelColors(selectedIndex: Int) {
    // Since icons use .alwaysOriginal, tintColor only affects the selected label text.
    // unselectedItemTintColor affects all unselected label text.
    // activeTextColors takes priority over activeColors for label text.
    let activeColor: UIColor? =
      (selectedIndex < currentActiveTextColors.count ? currentActiveTextColors[selectedIndex] : nil)
        .map { Self.colorFromARGB($0.intValue) }
      ?? (selectedIndex < currentActiveColors.count ? currentActiveColors[selectedIndex] : nil)
        .map { Self.colorFromARGB($0.intValue) }
    let inactiveColor: UIColor? =
      currentInactiveTextColors.compactMap { $0 }.first.map { Self.colorFromARGB($0.intValue) }
      ?? currentInactiveColors.compactMap { $0 }.first.map { Self.colorFromARGB($0.intValue) }
    if let left = tabBarLeft, let right = tabBarRight {
      let leftCount = left.items?.count ?? 0
      if let c = activeColor {
        if selectedIndex < leftCount { left.tintColor = c } else { right.tintColor = c }
      }
      if #available(iOS 10.0, *), let c = inactiveColor {
        left.unselectedItemTintColor = c
        right.unselectedItemTintColor = c
      }
    } else if let bar = tabBar {
      if let c = activeColor { bar.tintColor = c }
      if #available(iOS 10.0, *), let c = inactiveColor { bar.unselectedItemTintColor = c }
    }
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    // Single bar case
    if let single = self.tabBar, single === tabBar, let items = single.items, let idx = items.firstIndex(of: item) {
      channel.invokeMethod("valueChanged", arguments: ["index": idx])
      return
    }
    // Split left
    if let left = tabBarLeft, left === tabBar, let items = left.items, let idx = items.firstIndex(of: item) {
      tabBarRight?.selectedItem = nil
      channel.invokeMethod("valueChanged", arguments: ["index": idx])
      return
    }
    // Split right
    if let right = tabBarRight, right === tabBar, let items = right.items, let idx = items.firstIndex(of: item), let left = tabBarLeft, let leftItems = left.items {
      tabBarLeft?.selectedItem = nil
      channel.invokeMethod("valueChanged", arguments: ["index": leftItems.count + idx])
      return
    }
  }

  private static func colorFromARGB(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
}
