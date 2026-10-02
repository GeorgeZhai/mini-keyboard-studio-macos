import Foundation
import MiniKeyboardCore

private var failures = 0
private var checks = 0

@MainActor
private func check(
  _ condition: @autoclosure () -> Bool,
  _ message: String,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  checks += 1
  guard condition() else {
    failures += 1
    fputs("FAIL \(file):\(line): \(message)\n", stderr)
    return
  }
}

@MainActor
private func checkThrows(
  _ expected: ProtocolEncodingError,
  _ message: String,
  operation: () throws -> Void
) {
  checks += 1
  do {
    try operation()
    failures += 1
    fputs("FAIL: \(message): expected \(expected)\n", stderr)
  } catch let error as ProtocolEncodingError {
    if error != expected {
      failures += 1
      fputs("FAIL: \(message): got \(error), expected \(expected)\n", stderr)
    }
  } catch {
    failures += 1
    fputs("FAIL: \(message): unexpected error \(error)\n", stderr)
  }
}

@MainActor
private func checkReport(
  _ report: [UInt8],
  startsWith expected: [UInt8],
  _ message: String
) {
  check(report.count == ProtocolEncoder.reportLength, "\(message): report length")
  check(Array(report.prefix(expected.count)) == expected, "\(message): bytes")
  check(report.dropFirst(expected.count).allSatisfy { $0 == 0 }, "\(message): zero padding")
}

@MainActor
private func testProtocolEncoder() throws {
  let encoder = ProtocolEncoder()
  let shortcut = KeyAssignment(steps: [
    MacroStep(modifiers: ModifierKey.command.rawValue, keyCode: 0x06),
    MacroStep(modifiers: ModifierKey.shift.rawValue, keyCode: 0x19),
  ])
  let vendor = try encoder.reports(
    slot: 1, layer: 1, assignment: shortcut, protocol: .vendorV0211
  )
  check(vendor.count == 4, "vendor shortcut report count")
  checkReport(
    vendor[0], startsWith: [0x03, 0x01, 0x01, 0x02, 0x00, 0x08, 0x00, 0x00, 0x00], "vendor header")
  checkReport(
    vendor[1], startsWith: [0x03, 0x01, 0x01, 0x02, 0x01, 0x08, 0x06, 0x00, 0x00], "vendor step 1")
  checkReport(
    vendor[2], startsWith: [0x03, 0x01, 0x01, 0x02, 0x02, 0x02, 0x19, 0x00, 0x00], "vendor step 2")
  checkReport(vendor[3], startsWith: [0x03, 0xAA, 0xAA], "vendor commit")

  let controlA = KeyAssignment(steps: [
    MacroStep(modifiers: ModifierKey.control.rawValue, keyCode: 0x04)
  ])
  let layered = try encoder.reports(
    slot: 2, layer: 3, assignment: controlA, protocol: .layered8890
  )
  check(layered.count == 4, "layered shortcut report count")
  checkReport(layered[0], startsWith: [0x03, 0xA1, 0x03], "layer select")
  checkReport(
    layered[1], startsWith: [0x03, 0x02, 0x31, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00], "layered header"
  )
  checkReport(
    layered[2], startsWith: [0x03, 0x02, 0x31, 0x01, 0x01, 0x01, 0x04, 0x00, 0x00], "layered key")
  checkReport(layered[3], startsWith: [0x03, 0xAA, 0xAA], "layered commit")

  let alternate = try encoder.reports(
    slot: 15,
    layer: 2,
    assignment: KeyAssignment(kind: .media, mediaAction: .volumeUp),
    protocol: .alternate8890
  )
  check(alternate.count == 3, "alternate media report count")
  checkReport(
    alternate[0], startsWith: [0x03, 0xFE, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00],
    "alternate preamble")
  checkReport(
    alternate[1], startsWith: [0x03, 0x0F, 0x22, 0xE9, 0x00, 0x00, 0x00, 0x00, 0x00],
    "alternate media")
  checkReport(alternate[2], startsWith: [0x03, 0xAA, 0xAA], "alternate commit")

  let playPause = try encoder.reports(
    slot: 3,
    layer: 1,
    assignment: KeyAssignment(kind: .media, mediaAction: .playPause),
    protocol: .vendorV0211
  )
  checkReport(
    playPause[0], startsWith: [0x03, 0x03, 0x02, 0xCD, 0x00, 0x00, 0x00, 0x00, 0x00],
    "media little endian")

  let mouse = try encoder.reports(
    slot: 13,
    layer: 1,
    assignment: KeyAssignment(kind: .mouse, mouseAction: .scrollDown),
    protocol: .vendorV0211
  )
  checkReport(
    mouse[0], startsWith: [0x03, 0x0D, 0x03, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00], "mouse scroll")

  let disabled = try encoder.reports(
    slot: 1,
    layer: 1,
    assignment: KeyAssignment(kind: .disabled),
    protocol: .vendorV0211
  )
  check(disabled.count == 3, "disabled report count")
  checkReport(
    disabled[0], startsWith: [0x03, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00],
    "disabled header")
  checkReport(
    disabled[1], startsWith: [0x03, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00], "disabled key")

  let batch = try encoder.reports(
    for: [
      (slot: 1, assignment: KeyAssignment(kind: .media, mediaAction: .mute)),
      (slot: 2, assignment: KeyAssignment(kind: .media, mediaAction: .volumeDown)),
    ],
    layer: 1,
    protocol: .vendorV0211
  )
  check(batch.count == 4, "save-all batch report count")
  checkReport(
    batch[0], startsWith: [0x03, 0x01, 0x02, 0xE2, 0x00, 0x00, 0x00, 0x00, 0x00],
    "save-all first control")
  checkReport(batch[1], startsWith: [0x03, 0xAA, 0xAA], "save-all first commit")
  checkReport(
    batch[2], startsWith: [0x03, 0x02, 0x02, 0xEA, 0x00, 0x00, 0x00, 0x00, 0x00],
    "save-all second control")
  checkReport(batch[3], startsWith: [0x03, 0xAA, 0xAA], "save-all second commit")

  let vendorLight = encoder.backlightReports(mode: 9, protocol: .vendorV0211)
  checkReport(vendorLight[0], startsWith: [0x03, 0xB0, 0x08, 0x02], "vendor backlight clamp")
  checkReport(vendorLight[1], startsWith: [0x03, 0xAA, 0xA1], "backlight commit")
  let layeredLight = encoder.backlightReports(mode: 1, protocol: .layered8890)
  checkReport(layeredLight[0], startsWith: [0x03, 0xB0, 0x18, 0x01], "layered backlight")

  checkThrows(.invalidLayer, "invalid layer") {
    _ = try encoder.reports(slot: 1, layer: 0, assignment: KeyAssignment(), protocol: .vendorV0211)
  }
  checkThrows(.invalidSlot, "invalid slot") {
    _ = try encoder.reports(slot: 0, layer: 1, assignment: KeyAssignment(), protocol: .vendorV0211)
  }
  checkThrows(.emptyMacro, "empty macro") {
    _ = try encoder.reports(
      slot: 1, layer: 1, assignment: KeyAssignment(steps: []), protocol: .vendorV0211
    )
  }
  checkThrows(.macroTooLong, "macro too long") {
    _ = try encoder.reports(
      slot: 1,
      layer: 1,
      assignment: KeyAssignment(steps: Array(repeating: MacroStep(), count: 6)),
      protocol: .vendorV0211
    )
  }
}

@MainActor
private func testModels() {
  check(
    ControlTarget.targets(for: .threeKeysOneKnob).map(\.slot) == [1, 2, 3, 13, 14, 15],
    "three-key layout slots"
  )
  check(
    ControlTarget.targets(for: .sixKeysOneKnob).map(\.slot) == [1, 2, 3, 4, 5, 6, 13, 14, 15],
    "six-key layout slots"
  )
  check(
    ControlTarget.targets(for: .sixKeysTwoKnobs).map(\.slot) == [
      1, 2, 3, 4, 5, 6, 13, 14, 15, 16, 17, 18,
    ],
    "two-knob layout slots"
  )
  check(
    ControlTarget.targets(for: .twelveKeysTwoKnobs).map(\.slot)
      == Array(1...18).map(UInt8.init),
    "twelve-key layout slots"
  )

  let targets = ControlTarget.targets(for: .threeKeysOneKnob)
  check(targets[0].title == "Key 1", "key title")
  check(targets[3].title == "Knob 1 · Left", "knob left title")
  check(targets[4].title == "Knob 1 · Press", "knob press title")
  check(targets[5].title == "Knob 1 · Right", "knob right title")

  check(Set(HIDKey.all.map(\.code)).count == HIDKey.all.count, "HID key codes are unique")
  check(HIDKey.label(for: 0x04) == "A", "HID A")
  check(HIDKey.label(for: 0x1D) == "Z", "HID Z")
  check(HIDKey.label(for: 0x3A) == "F1", "HID F1")
  check(HIDKey.label(for: 0x73) == "F24", "HID F24")
  check(HIDKey.label(for: 0xFF) == "0xFF", "unknown HID label")

  check(MediaAction.playPause.usage == 0x00CD, "play/pause usage")
  check(MediaAction.mute.usage == 0x00E2, "mute usage")
  check(MediaAction.volumeUp.usage == 0x00E9, "volume up usage")
  check(MediaAction.volumeDown.usage == 0x00EA, "volume down usage")

  check(Preset.copy.assignment.summary == "⌘C", "copy preset")
  check(Preset.paste.assignment.summary == "⌘V", "paste preset")
  check(Preset.undo.assignment.summary == "⌘Z", "undo preset")
  check(Preset.playPause.assignment.summary == "Play / Pause", "play/pause preset")
  check(Preset.missionControl.assignment.summary == "F13", "Mission Control preset")

  check(!KeyboardProtocol.vendorV0211.supportsLayers, "V02.1.1 is single-layer")
  check(KeyboardProtocol.layered8890.supportsLayers, "layered protocol supports layers")
  check(KeyboardProtocol.alternate8890.supportsLayers, "alternate protocol supports layers")

  let withID = USBTransport.ReportInfo(reportID: 3, payloadLength: 64)
  check(withID.wireLength == 65, "report ID adds one wire byte")
  let withoutID = USBTransport.ReportInfo(reportID: 0, payloadLength: 64)
  check(withoutID.wireLength == 64, "report without ID uses payload length")
}

do {
  try testProtocolEncoder()
  testModels()
} catch {
  failures += 1
  fputs("FAIL: unexpected top-level error: \(error)\n", stderr)
}

if failures == 0 {
  print("passed: \(checks) MiniKeyboardCore checks")
  exit(EXIT_SUCCESS)
} else {
  fputs("failed: \(failures) of \(checks) checks\n", stderr)
  exit(EXIT_FAILURE)
}
