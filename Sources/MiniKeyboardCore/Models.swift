import Foundation

public enum KeyboardProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
  case vendorV0211
  case layered8890
  case alternate8890

  public var id: String { rawValue }

  public var supportsLayers: Bool {
    self != .vendorV0211
  }

  public var title: String {
    switch self {
    case .vendorV0211: "V02.1.1"
    case .layered8890: "Layered 8890"
    case .alternate8890: "FE preamble"
    }
  }

  public var detail: String {
    switch self {
    case .vendorV0211:
      "Matches the single-layer Windows configurator you linked. Try this first."
    case .layered8890:
      "Hardware-tested 8890 variant with host-selectable layers."
    case .alternate8890:
      "For 8890 firmware that expects the FE preamble used by other batches."
    }
  }
}

public enum HardwareLayout: String, Codable, CaseIterable, Identifiable, Sendable {
  case threeKeysOneKnob
  case sixKeysOneKnob
  case sixKeysTwoKnobs
  case twelveKeysTwoKnobs

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .threeKeysOneKnob: "3 keys + 1 knob"
    case .sixKeysOneKnob: "6 keys + 1 knob"
    case .sixKeysTwoKnobs: "6 keys + 2 knobs"
    case .twelveKeysTwoKnobs: "12 keys + 2 knobs"
    }
  }

  public var buttonCount: Int {
    switch self {
    case .threeKeysOneKnob: 3
    case .sixKeysOneKnob, .sixKeysTwoKnobs: 6
    case .twelveKeysTwoKnobs: 12
    }
  }

  public var knobCount: Int {
    switch self {
    case .threeKeysOneKnob, .sixKeysOneKnob: 1
    case .sixKeysTwoKnobs, .twelveKeysTwoKnobs: 2
    }
  }

  public var columns: Int {
    switch self {
    case .threeKeysOneKnob: 3
    case .sixKeysOneKnob, .sixKeysTwoKnobs, .twelveKeysTwoKnobs: 3
    }
  }
}

public struct ControlTarget: Identifiable, Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    case button(index: Int)
    case knob(index: Int, action: KnobAction)
  }

  public enum KnobAction: Int, Hashable, Sendable {
    case counterClockwise = 0
    case press = 1
    case clockwise = 2
  }

  public let slot: UInt8
  public let kind: Kind

  public var id: String { "slot-\(slot)" }

  public var title: String {
    switch kind {
    case .button(let index): "Key \(index)"
    case .knob(let index, .counterClockwise): "Knob \(index) · Left"
    case .knob(let index, .press): "Knob \(index) · Press"
    case .knob(let index, .clockwise): "Knob \(index) · Right"
    }
  }

  public static func targets(for layout: HardwareLayout) -> [ControlTarget] {
    var result = (1...layout.buttonCount).map {
      ControlTarget(slot: UInt8($0), kind: .button(index: $0))
    }
    for knobIndex in 1...layout.knobCount {
      let base = 13 + ((knobIndex - 1) * 3)
      result.append(
        ControlTarget(
          slot: UInt8(base),
          kind: .knob(index: knobIndex, action: .counterClockwise)
        ))
      result.append(
        ControlTarget(
          slot: UInt8(base + 1),
          kind: .knob(index: knobIndex, action: .press)
        ))
      result.append(
        ControlTarget(
          slot: UInt8(base + 2),
          kind: .knob(index: knobIndex, action: .clockwise)
        ))
    }
    return result
  }
}

public enum AssignmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case shortcut
  case media
  case mouse
  case disabled

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .shortcut: "Shortcut / Macro"
    case .media: "Media"
    case .mouse: "Mouse"
    case .disabled: "Disabled"
    }
  }
}

public struct MacroStep: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var modifiers: UInt8
  public var keyCode: UInt8

  public init(id: UUID = UUID(), modifiers: UInt8 = 0, keyCode: UInt8 = 0x04) {
    self.id = id
    self.modifiers = modifiers
    self.keyCode = keyCode
  }
}

public enum ModifierKey: UInt8, CaseIterable, Identifiable, Sendable {
  case control = 0x01
  case shift = 0x02
  case option = 0x04
  case command = 0x08

  public var id: UInt8 { rawValue }

  public var symbol: String {
    switch self {
    case .control: "⌃"
    case .shift: "⇧"
    case .option: "⌥"
    case .command: "⌘"
    }
  }

  public var name: String {
    switch self {
    case .control: "Control"
    case .shift: "Shift"
    case .option: "Option"
    case .command: "Command"
    }
  }
}

public struct HIDKey: Identifiable, Hashable, Sendable {
  public let code: UInt8
  public let label: String
  public let group: String

  public var id: UInt8 { code }

  public init(_ code: UInt8, _ label: String, group: String) {
    self.code = code
    self.label = label
    self.group = group
  }

  public static let all: [HIDKey] = {
    var keys: [HIDKey] = []
    for (offset, character) in Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").enumerated() {
      keys.append(HIDKey(UInt8(0x04 + offset), String(character), group: "Letters"))
    }
    for (offset, character) in Array("1234567890").enumerated() {
      keys.append(HIDKey(UInt8(0x1E + offset), String(character), group: "Numbers"))
    }
    keys.append(contentsOf: [
      HIDKey(0x28, "Return", group: "Common"),
      HIDKey(0x29, "Escape", group: "Common"),
      HIDKey(0x2A, "Delete ⌫", group: "Common"),
      HIDKey(0x2B, "Tab", group: "Common"),
      HIDKey(0x2C, "Space", group: "Common"),
      HIDKey(0x2D, "-", group: "Punctuation"),
      HIDKey(0x2E, "=", group: "Punctuation"),
      HIDKey(0x2F, "[", group: "Punctuation"),
      HIDKey(0x30, "]", group: "Punctuation"),
      HIDKey(0x31, "\\", group: "Punctuation"),
      HIDKey(0x33, ";", group: "Punctuation"),
      HIDKey(0x34, "'", group: "Punctuation"),
      HIDKey(0x35, "`", group: "Punctuation"),
      HIDKey(0x36, ",", group: "Punctuation"),
      HIDKey(0x37, ".", group: "Punctuation"),
      HIDKey(0x38, "/", group: "Punctuation"),
      HIDKey(0x39, "Caps Lock", group: "Common"),
      HIDKey(0x4A, "Home", group: "Navigation"),
      HIDKey(0x4B, "Page Up", group: "Navigation"),
      HIDKey(0x4C, "Forward Delete", group: "Navigation"),
      HIDKey(0x4D, "End", group: "Navigation"),
      HIDKey(0x4E, "Page Down", group: "Navigation"),
      HIDKey(0x4F, "Right Arrow", group: "Navigation"),
      HIDKey(0x50, "Left Arrow", group: "Navigation"),
      HIDKey(0x51, "Down Arrow", group: "Navigation"),
      HIDKey(0x52, "Up Arrow", group: "Navigation"),
    ])
    for number in 1...12 {
      keys.append(HIDKey(UInt8(0x39 + number), "F\(number)", group: "Function"))
    }
    for number in 13...24 {
      keys.append(HIDKey(UInt8(0x68 + number - 13), "F\(number)", group: "Function"))
    }
    return keys
  }()

  public static func label(for code: UInt8) -> String {
    all.first(where: { $0.code == code })?.label ?? String(format: "0x%02X", code)
  }
}

public enum MediaAction: String, Codable, CaseIterable, Identifiable, Sendable {
  case playPause
  case nextTrack
  case previousTrack
  case stop
  case volumeUp
  case volumeDown
  case mute

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .playPause: "Play / Pause"
    case .nextTrack: "Next Track"
    case .previousTrack: "Previous Track"
    case .stop: "Stop"
    case .volumeUp: "Volume Up"
    case .volumeDown: "Volume Down"
    case .mute: "Mute"
    }
  }

  public var usage: UInt16 {
    switch self {
    case .nextTrack: 0x00B5
    case .previousTrack: 0x00B6
    case .stop: 0x00B7
    case .playPause: 0x00CD
    case .mute: 0x00E2
    case .volumeUp: 0x00E9
    case .volumeDown: 0x00EA
    }
  }
}

public enum MouseAction: String, Codable, CaseIterable, Identifiable, Sendable {
  case leftClick
  case rightClick
  case middleClick
  case scrollUp
  case scrollDown

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .leftClick: "Left Click"
    case .rightClick: "Right Click"
    case .middleClick: "Middle Click"
    case .scrollUp: "Scroll Up"
    case .scrollDown: "Scroll Down"
    }
  }

  public var payload: (button: UInt8, x: UInt8, y: UInt8, wheel: UInt8, modifier: UInt8) {
    switch self {
    case .leftClick: (0x01, 0, 0, 0, 0)
    case .rightClick: (0x02, 0, 0, 0, 0)
    case .middleClick: (0x04, 0, 0, 0, 0)
    case .scrollUp: (0, 0, 0, 0x01, 0)
    case .scrollDown: (0, 0, 0, 0xFF, 0)
    }
  }
}

public struct KeyAssignment: Codable, Equatable, Sendable {
  public var kind: AssignmentKind
  public var steps: [MacroStep]
  public var mediaAction: MediaAction
  public var mouseAction: MouseAction

  public init(
    kind: AssignmentKind = .shortcut,
    steps: [MacroStep] = [MacroStep()],
    mediaAction: MediaAction = .playPause,
    mouseAction: MouseAction = .leftClick
  ) {
    self.kind = kind
    self.steps = steps
    self.mediaAction = mediaAction
    self.mouseAction = mouseAction
  }

  public var summary: String {
    switch kind {
    case .disabled:
      return "Disabled"
    case .media:
      return mediaAction.title
    case .mouse:
      return mouseAction.title
    case .shortcut:
      return steps.map { step in
        let symbols = ModifierKey.allCases
          .filter { step.modifiers & $0.rawValue != 0 }
          .map(\.symbol)
          .joined()
        return symbols + HIDKey.label(for: step.keyCode)
      }.joined(separator: "  →  ")
    }
  }
}

public enum Preset: String, CaseIterable, Identifiable, Sendable {
  case copy
  case paste
  case undo
  case playPause
  case volumeDown
  case volumeUp
  case missionControl

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .copy: "Copy"
    case .paste: "Paste"
    case .undo: "Undo"
    case .playPause: "Play / Pause"
    case .volumeDown: "Volume Down"
    case .volumeUp: "Volume Up"
    case .missionControl: "Mission Control (F13)"
    }
  }

  public var assignment: KeyAssignment {
    switch self {
    case .copy:
      KeyAssignment(steps: [MacroStep(modifiers: ModifierKey.command.rawValue, keyCode: 0x06)])
    case .paste:
      KeyAssignment(steps: [MacroStep(modifiers: ModifierKey.command.rawValue, keyCode: 0x19)])
    case .undo:
      KeyAssignment(steps: [MacroStep(modifiers: ModifierKey.command.rawValue, keyCode: 0x1D)])
    case .playPause:
      KeyAssignment(kind: .media, mediaAction: .playPause)
    case .volumeDown:
      KeyAssignment(kind: .media, mediaAction: .volumeDown)
    case .volumeUp:
      KeyAssignment(kind: .media, mediaAction: .volumeUp)
    case .missionControl:
      KeyAssignment(steps: [MacroStep(keyCode: 0x68)])
    }
  }
}
