import FlutterMacOS
import Cocoa

class CupertinoTabBarNSView: NSView {
  private let channel: FlutterMethodChannel
  private let control: NSSegmentedControl
  private var currentLabels: [String] = []
  private var currentActiveSymbols: [String] = []
  private var currentInactiveSymbols: [String] = []
  private var currentSizes: [NSNumber] = []
  private var currentActiveColors: [NSNumber?] = []
  private var currentInactiveColors: [NSNumber?] = []
  private var currentTint: NSColor? = nil
  private var currentBackground: NSColor? = nil
  private var blurOverlay: NSVisualEffectView?

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeTabBar_\(viewId)", binaryMessenger: messenger)
    self.control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)

    var labels: [String] = []
    var activeSymbols: [String] = []
    var inactiveSymbols: [String] = []
    var sizes: [NSNumber] = []
    var activeColors: [NSNumber?] = []
    var inactiveColors: [NSNumber?] = []
    var selectedIndex: Int = 0
    var isDark: Bool = false
    var tint: NSColor? = nil
    var bg: NSColor? = nil
    var blurred: Bool = false

    if let dict = args as? [String: Any] {
      labels = (dict["labels"] as? [String]) ?? []
      let fallbackSymbols = (dict["sfSymbols"] as? [String]) ?? []
      activeSymbols = (dict["activeSymbols"] as? [String]) ?? fallbackSymbols
      inactiveSymbols = (dict["inactiveSymbols"] as? [String]) ?? fallbackSymbols
      sizes = (dict["sfSymbolSizes"] as? [NSNumber]) ?? []
      activeColors = (dict["activeColors"] as? [NSNumber?]) ?? []
      inactiveColors = (dict["inactiveColors"] as? [NSNumber?]) ?? []
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["backgroundColor"] as? NSNumber { bg = Self.colorFromARGB(n.intValue) }
      }
      if let b = dict["blurred"] as? NSNumber { blurred = b.boolValue }
    }

    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    configureSegments(labels: labels, activeSymbols: activeSymbols, inactiveSymbols: inactiveSymbols, sizes: sizes, selectedIndex: selectedIndex)
    if selectedIndex >= 0 { control.selectedSegment = selectedIndex }
    // Save current style and content for retinting
    self.currentLabels = labels
    self.currentActiveSymbols = activeSymbols
    self.currentInactiveSymbols = inactiveSymbols
    self.currentSizes = sizes
    self.currentActiveColors = activeColors
    self.currentInactiveColors = inactiveColors
    self.currentTint = tint
    self.currentBackground = bg
    if let b = bg { wantsLayer = true; layer?.backgroundColor = b.cgColor }
    applySegmentTint()

    control.target = self
    control.action = #selector(onChanged(_:))

    addSubview(control)
    if blurred { setBlurred(true) }
    control.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: leadingAnchor),
      control.trailingAnchor.constraint(equalTo: trailingAnchor),
      control.topAnchor.constraint(equalTo: topAnchor),
      control.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        let size = self.control.intrinsicContentSize
        result(["width": Double(size.width), "height": Double(size.height)])
      case "setSelectedIndex":
        if let args = call.arguments as? [String: Any], let idx = (args["index"] as? NSNumber)?.intValue {
          self.control.selectedSegment = idx
          self.applySegmentTint()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["tint"] as? NSNumber { self.currentTint = Self.colorFromARGB(n.intValue) }
          if let n = args["backgroundColor"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            self.currentBackground = c
            self.wantsLayer = true
            self.layer?.backgroundColor = c.cgColor
          }
          self.applySegmentTint()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
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

  required init?(coder: NSCoder) { return nil }

  override func layout() {
    super.layout()
    blurOverlay?.frame = bounds
  }

  private func setBlurred(_ blurred: Bool) {
    if blurred {
      guard blurOverlay == nil else { return }
      let overlay = NSVisualEffectView(frame: bounds)
      overlay.autoresizingMask = [.width, .height]
      overlay.material = .sheet
      overlay.blendingMode = .withinWindow
      overlay.state = .active
      addSubview(overlay)
      blurOverlay = overlay
    } else {
      blurOverlay?.removeFromSuperview()
      blurOverlay = nil
    }
  }

  private func configureSegments(labels: [String], activeSymbols: [String], inactiveSymbols: [String], sizes: [NSNumber], selectedIndex: Int) {
    let count = max(labels.count, max(activeSymbols.count, inactiveSymbols.count))
    control.segmentCount = count
    for i in 0..<count {
      let isSelected = (i == selectedIndex)
      let symArr = isSelected ? activeSymbols : inactiveSymbols
      let name = i < symArr.count ? symArr[i] : ""
      if !name.isEmpty, #available(macOS 11.0, *), var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
        if i < sizes.count, #available(macOS 12.0, *) {
          let size = CGFloat(truncating: sizes[i])
          let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
          image = image.withSymbolConfiguration(cfg) ?? image
        }
        control.setImage(image, forSegment: i)
      } else if i < labels.count {
        control.setLabel(labels[i], forSegment: i)
      } else {
        control.setLabel("", forSegment: i)
      }
    }
  }

  private func applySegmentTint() {
    let count = control.segmentCount
    guard count > 0 else { return }
    let sel = control.selectedSegment
    for i in 0..<count {
      let isSelected = (i == sel)
      let symArr = isSelected ? currentActiveSymbols : currentInactiveSymbols
      let colorArr = isSelected ? currentActiveColors : currentInactiveColors
      let name = i < symArr.count ? symArr[i] : ""
      guard !name.isEmpty, #available(macOS 11.0, *),
            var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { continue }
      if i < currentSizes.count, #available(macOS 12.0, *) {
        let size = CGFloat(truncating: currentSizes[i])
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        image = image.withSymbolConfiguration(cfg) ?? image
      }
      let perItemColor: NSColor? = (i < colorArr.count ? colorArr[i] : nil).map { Self.colorFromARGB($0.intValue) }
      let colorToApply = perItemColor ?? (isSelected ? currentTint : nil)
      if let color = colorToApply {
        if #available(macOS 12.0, *) {
          let cfg = NSImage.SymbolConfiguration(hierarchicalColor: color)
          image = image.withSymbolConfiguration(cfg) ?? image
        } else {
          image = image.tinted(with: color)
        }
      }
      control.setImage(image, forSegment: i)
    }
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }

  @objc private func onChanged(_ sender: NSSegmentedControl) {
    channel.invokeMethod("valueChanged", arguments: ["index": sender.selectedSegment])
  }
}

private extension NSImage {
  func tinted(with color: NSColor) -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    color.set()
    rect.fill()
    draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
    img.unlockFocus()
    return img
  }
}
