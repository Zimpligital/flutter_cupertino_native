import FlutterMacOS
import Cocoa

class CupertinoPopupMenuButtonNSView: NSView {
  private let channel: FlutterMethodChannel
  private let button: NSButton
  private var popupMenu: NSMenu = NSMenu()
  private var labels: [String] = []
  private var symbols: [String] = []
  private var dividers: [Bool] = []
  private var enabled: [Bool] = []
  private var checked: [Bool] = []
  private var defaultSizes: [NSNumber?] = []
  private var defaultColors: [NSNumber?] = []
  private var defaultModes: [String?] = []
  private var defaultPalettes: [[NSNumber]] = []
  private var defaultGradients: [NSNumber?] = []
  private var defaultLabelColors: [NSNumber?] = []
  private var isTransparentOverlay: Bool = false
  private var blurOverlay: NSVisualEffectView?

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativePopupMenuButton_\(viewId)", binaryMessenger: messenger)
    self.button = NSButton(title: "", target: nil, action: nil)
    super.init(frame: .zero)

    var title: String? = nil
    var iconName: String? = nil
    var iconSize: CGFloat? = nil
    var iconColor: NSColor? = nil
    var makeRound: Bool = false
    var buttonStyle: String = "automatic"
    var isDark: Bool = false
    var tint: NSColor? = nil
    var labels: [String] = []
    var symbols: [String] = []
    var dividers: [NSNumber] = []
    var enabled: [NSNumber] = []
    var checkedNums: [NSNumber] = []
    var sizes: [NSNumber?] = []
    var colors: [NSNumber?] = []
    var buttonIconMode: String? = nil
    var buttonIconPalette: [NSNumber] = []
    var transparentOverlay: Bool = false
    var blurred: Bool = false

    if let dict = args as? [String: Any] {
      if let t = dict["transparentOverlay"] as? NSNumber { transparentOverlay = t.boolValue }
      if let b = dict["blurred"] as? NSNumber { blurred = b.boolValue }
      if let t = dict["buttonTitle"] as? String { title = t }
      if let s = dict["buttonIconName"] as? String { iconName = s }
      if let s = dict["buttonIconSize"] as? NSNumber { iconSize = CGFloat(truncating: s) }
      if let c = dict["buttonIconColor"] as? NSNumber { iconColor = Self.colorFromARGB(c.intValue) }
      if let r = dict["round"] as? NSNumber { makeRound = r.boolValue }
      if let bs = dict["buttonStyle"] as? String { buttonStyle = bs }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
      labels = (dict["labels"] as? [String]) ?? []
      symbols = (dict["sfSymbols"] as? [String]) ?? []
      dividers = (dict["isDivider"] as? [NSNumber]) ?? []
      enabled = (dict["enabled"] as? [NSNumber]) ?? []
      checkedNums = (dict["checked"] as? [NSNumber]) ?? []
      self.defaultModes = Self.parseNullableStrings(dict["sfSymbolRenderingModes"])
      if let palettes = dict["sfSymbolPaletteColors"] as? [[NSNumber]] { self.defaultPalettes = palettes }
      self.defaultGradients = Self.parseNullableNumbers(dict["sfSymbolGradientEnabled"])
      self.defaultLabelColors = Self.parseNullableNumbers(dict["labelColors"])
      if let m = dict["buttonIconRenderingMode"] as? String { buttonIconMode = m }
      if let pal = dict["buttonIconPaletteColors"] as? [NSNumber] { buttonIconPalette = pal }
      sizes = Self.parseNullableNumbers(dict["sfSymbolSizes"])
      colors = Self.parseNullableNumbers(dict["sfSymbolColors"])
    }

    self.isTransparentOverlay = transparentOverlay

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    // Make button transparent when in overlay mode
    if transparentOverlay {
      button.title = ""
      button.image = nil
      button.isBordered = false
      button.bezelStyle = .texturedRounded
      // NSButton doesn't have backgroundColor, but isBordered = false makes it transparent
    } else {
      if let t = title { button.title = t }
      if let name = iconName, var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
      if #available(macOS 12.0, *), let sz = iconSize {
        let cfg = NSImage.SymbolConfiguration(pointSize: sz, weight: .regular)
        image = image.withSymbolConfiguration(cfg) ?? image
      }
      if let mode = buttonIconMode {
        switch mode {
        case "hierarchical":
          if #available(macOS 12.0, *), let c = iconColor {
            let cfg = NSImage.SymbolConfiguration(hierarchicalColor: c)
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        case "palette":
          if #available(macOS 12.0, *), !buttonIconPalette.isEmpty {
            let cols = buttonIconPalette.map { Self.colorFromARGB($0.intValue) }
            let cfg = NSImage.SymbolConfiguration(paletteColors: cols)
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        case "multicolor":
          if #available(macOS 12.0, *) {
            let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        default:
          break
        }
      } else if let c = iconColor {
        image = image.tinted(with: c)
      }
        button.image = image
        button.imagePosition = .imageOnly
      }
    }
    // Map CNButtonStyle to AppKit bezel styles (best-effort)
    switch buttonStyle {
    case "plain":
      button.bezelStyle = .texturedRounded
      button.isBordered = false
    case "gray": button.bezelStyle = .texturedRounded
    case "tinted": button.bezelStyle = .texturedRounded
    case "bordered": button.bezelStyle = .rounded
    case "borderedProminent": button.bezelStyle = .rounded
    case "filled": button.bezelStyle = .rounded
    case "glass": button.bezelStyle = .texturedRounded
    case "prominentGlass": button.bezelStyle = .texturedRounded
    default: button.bezelStyle = .rounded
    }
    if makeRound { button.bezelStyle = .circular }
    button.setButtonType(.momentaryPushIn)
    if #available(macOS 10.14, *), let c = tint {
      if ["filled", "borderedProminent", "prominentGlass"].contains(buttonStyle) {
        button.bezelColor = c
        button.contentTintColor = .white
      } else {
        button.contentTintColor = c
      }
    }

    addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: leadingAnchor),
      button.trailingAnchor.constraint(equalTo: trailingAnchor),
      button.topAnchor.constraint(equalTo: topAnchor),
      button.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    self.labels = labels
    self.symbols = symbols
    self.dividers = dividers.map { $0.boolValue }
    self.enabled = enabled.map { $0.boolValue }
    self.checked = checkedNums.map { $0.boolValue }
    self.defaultSizes = sizes
    self.defaultColors = colors
    rebuildMenu(defaultSizes: sizes, defaultColors: colors)

    button.target = self
    button.action = #selector(onButtonPressed(_:))
    if blurred { setBlurred(true) }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        let s = self.button.intrinsicContentSize
        result(["width": Double(s.width), "height": Double(s.height)])
      case "setItems":
        if let args = call.arguments as? [String: Any] {
          self.labels = (args["labels"] as? [String]) ?? []
          self.symbols = (args["sfSymbols"] as? [String]) ?? []
          self.dividers = ((args["isDivider"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.enabled = ((args["enabled"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.checked = ((args["checked"] as? [NSNumber]) ?? []).map { $0.boolValue }
          self.defaultSizes = Self.parseNullableNumbers(args["sfSymbolSizes"])
          self.defaultColors = Self.parseNullableNumbers(args["sfSymbolColors"])
          self.defaultModes = Self.parseNullableStrings(args["sfSymbolRenderingModes"])
          self.defaultPalettes = (args["sfSymbolPaletteColors"] as? [[NSNumber]]) ?? []
          self.defaultGradients = Self.parseNullableNumbers(args["sfSymbolGradientEnabled"])
          self.defaultLabelColors = Self.parseNullableNumbers(args["labelColors"])
          self.rebuildMenu(defaultSizes: self.defaultSizes, defaultColors: self.defaultColors)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing items", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if #available(macOS 10.14, *), let n = args["tint"] as? NSNumber {
            let color = Self.colorFromARGB(n.intValue)
            if ["filled", "borderedProminent", "prominentGlass"].contains(buttonStyle) {
              self.button.bezelColor = color
              self.button.contentTintColor = .white
            } else {
              self.button.contentTintColor = color
            }
          }
          if let bs = args["buttonStyle"] as? String {
            switch bs {
            case "plain":
              self.button.bezelStyle = .texturedRounded
              self.button.isBordered = false
            case "gray": self.button.bezelStyle = .texturedRounded
            case "tinted": self.button.bezelStyle = .texturedRounded
            case "bordered": self.button.bezelStyle = .rounded
            case "borderedProminent": self.button.bezelStyle = .rounded
            case "filled": self.button.bezelStyle = .rounded
            case "glass": self.button.bezelStyle = .texturedRounded
            case "prominentGlass": self.button.bezelStyle = .texturedRounded
            default: self.button.bezelStyle = .rounded
            }
            if bs != "plain" { self.button.isBordered = true }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setButtonIcon":
        if let args = call.arguments as? [String: Any] {
          if let name = args["buttonIconName"] as? String, var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            if #available(macOS 12.0, *), let sz = args["buttonIconSize"] as? NSNumber {
              let cfg = NSImage.SymbolConfiguration(pointSize: CGFloat(truncating: sz), weight: .regular)
              image = image.withSymbolConfiguration(cfg) ?? image
            }
            if let mode = args["buttonIconRenderingMode"] as? String {
              switch mode {
              case "hierarchical":
                if #available(macOS 12.0, *), let c = args["buttonIconColor"] as? NSNumber {
                  let cfg = NSImage.SymbolConfiguration(hierarchicalColor: Self.colorFromARGB(c.intValue))
                  image = image.withSymbolConfiguration(cfg) ?? image
                }
              case "palette":
                if #available(macOS 12.0, *), let pal = args["buttonIconPaletteColors"] as? [NSNumber] {
                  let cols = pal.map { Self.colorFromARGB($0.intValue) }
                  let cfg = NSImage.SymbolConfiguration(paletteColors: cols)
                  image = image.withSymbolConfiguration(cfg) ?? image
                }
              case "multicolor":
                if #available(macOS 12.0, *) {
                  let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
                  image = image.withSymbolConfiguration(cfg) ?? image
                }
              default:
                break
              }
            } else if let c = args["buttonIconColor"] as? NSNumber {
              image = image.tinted(with: Self.colorFromARGB(c.intValue))
            }
            self.button.image = image
            self.button.imagePosition = .imageOnly
          }
          if let r = args["round"] as? NSNumber, r.boolValue { self.button.bezelStyle = .circular }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing icon args", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setButtonTitle":
        if let args = call.arguments as? [String: Any], let t = args["title"] as? String {
          self.button.title = t
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing title", details: nil)) }
      case "setPressed":
        if let args = call.arguments as? [String: Any], let p = args["pressed"] as? NSNumber {
          self.alphaValue = p.boolValue ? 0.7 : 1.0
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing pressed", details: nil)) }
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

  @objc private func onButtonPressed(_ sender: NSButton) {
    let location = NSPoint(x: 0, y: sender.bounds.height)
    popupMenu.popUp(positioning: nil, at: location, in: sender)
  }

  private func rebuildMenu(defaultSizes: [NSNumber?]? = nil, defaultColors: [NSNumber?]? = nil) {
    popupMenu = NSMenu()
    popupMenu.autoenablesItems = false
    let count = max(labels.count, max(symbols.count, max(dividers.count, max(enabled.count, checked.count))))
    for i in 0..<count {
      if i < dividers.count, dividers[i] {
        popupMenu.addItem(.separator())
        continue
      }
      let title = i < labels.count ? labels[i] : ""
      let mi = NSMenuItem(title: title, action: #selector(onSelectMenuItem(_:)), keyEquivalent: "")
      mi.target = self
      mi.tag = i
      let isEnabled = i < enabled.count ? enabled[i] : true
      mi.isEnabled = isEnabled
      if i < checked.count { mi.state = checked[i] ? .on : .off }

      // Build the SF Symbol image (if any) first so it can be used in either path
      var finalImage: NSImage? = nil
      if i < symbols.count, !symbols[i].isEmpty {
        if var img = NSImage(systemSymbolName: symbols[i], accessibilityDescription: nil) {
          if #available(macOS 12.0, *), let sizes = defaultSizes, i < sizes.count, let sn = sizes[i] {
            let s = CGFloat(truncating: sn)
            if s > 0 {
              let cfg = NSImage.SymbolConfiguration(pointSize: s, weight: .regular)
              img = img.withSymbolConfiguration(cfg) ?? img
            }
          }
          if #available(macOS 12.0, *), i < defaultModes.count, let mode = defaultModes[i] {
            switch mode {
            case "hierarchical":
              if let colors = defaultColors, i < colors.count, let cn = colors[i] {
                let c = Self.colorFromARGB(cn.intValue)
                let cfg = NSImage.SymbolConfiguration(hierarchicalColor: c)
                img = img.withSymbolConfiguration(cfg) ?? img
              }
            case "palette":
              if i < defaultPalettes.count, !defaultPalettes[i].isEmpty {
                let cols = defaultPalettes[i].map { Self.colorFromARGB($0.intValue) }
                let cfg = NSImage.SymbolConfiguration(paletteColors: cols)
                img = img.withSymbolConfiguration(cfg) ?? img
              }
            case "multicolor":
              let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
              img = img.withSymbolConfiguration(cfg) ?? img
            case "monochrome":
              if let colors = defaultColors, i < colors.count, let cn = colors[i] {
                let c = Self.colorFromARGB(cn.intValue)
                img = img.tinted(with: c)
              }
            default:
              break
            }
          } else if #available(macOS 12.0, *), let colors = defaultColors, i < colors.count, let cn = colors[i] {
            let c = Self.colorFromARGB(cn.intValue)
            let cfg = NSImage.SymbolConfiguration(hierarchicalColor: c)
            img = img.withSymbolConfiguration(cfg) ?? img
          }
          finalImage = img
        }
      }

      // Use a custom view for colored labels (NSMenuItem.attributedTitle foreground
      // color is not reliably respected on macOS 14+); fall back to standard image.
      if i < defaultLabelColors.count, let lc = defaultLabelColors[i] {
        let color = Self.colorFromARGB(lc.intValue)
        mi.view = ColoredMenuItemView(title: title, color: color, image: finalImage)
      } else {
        if let img = finalImage { mi.image = img }
      }

      popupMenu.addItem(mi)
    }
  }

  @objc private func onSelectMenuItem(_ sender: NSMenuItem) {
    channel.invokeMethod("itemSelected", arguments: ["index": sender.tag])
  }

  // Custom view for menu items that need a specific label color.
  // NSMenuItem.attributedTitle foreground color is not reliably respected on macOS 14+,
  // so we use NSMenuItem.view with a lightweight NSView instead.
  private class ColoredMenuItemView: NSView {
    private let label: NSTextField
    private let iconView: NSImageView
    private let customColor: NSColor

    init(title: String, color: NSColor, image: NSImage?) {
      self.customColor = color
      self.label = NSTextField(labelWithString: title)
      self.iconView = NSImageView()
      // Non-zero height so NSMenu can determine the item height from the frame.
      super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 22))

      let hasIcon = image != nil
      let iconSize: CGFloat = 16
      let leading: CGFloat = 18

      if let img = image {
        iconView.image = img
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
      }

      label.font = NSFont.menuFont(ofSize: 0)
      label.textColor = color
      label.isBordered = false
      label.isEditable = false
      label.drawsBackground = false
      label.translatesAutoresizingMaskIntoConstraints = false
      addSubview(label)

      var constraints: [NSLayoutConstraint] = [
        label.centerYAnchor.constraint(equalTo: centerYAnchor),
        trailingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 18),
      ]
      if hasIcon {
        constraints += [
          iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
          iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
          iconView.widthAnchor.constraint(equalToConstant: iconSize),
          iconView.heightAnchor.constraint(equalToConstant: iconSize),
          label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
        ]
      } else {
        constraints.append(label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading + iconSize + 6))
      }
      NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) { return nil }

    private func updateColors() {
      let highlighted = enclosingMenuItem?.isHighlighted == true
      label.textColor = highlighted ? .selectedMenuItemTextColor : customColor
    }

    override func draw(_ dirtyRect: NSRect) {
      updateColors()
      super.draw(dirtyRect)
    }
  }

  private static func parseNullableNumbers(_ value: Any?) -> [NSNumber?] {
    guard let arr = value as? [Any] else { return [] }
    return arr.map { $0 is NSNull ? nil : $0 as? NSNumber }
  }

  private static func parseNullableStrings(_ value: Any?) -> [String?] {
    guard let arr = value as? [Any] else { return [] }
    return arr.map { $0 is NSNull ? nil : $0 as? String }
  }

  private static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
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
