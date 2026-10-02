import Foundation
import MiniKeyboardCore

if CommandLine.arguments.contains("--apply-starter-preset") {
  let transport = USBTransport()
  let encoder = ProtocolEncoder()
  let preset: [(label: String, slot: UInt8, assignment: KeyAssignment)] = [
    (
      "Key 1: Copy",
      1,
      KeyAssignment(steps: [
        MacroStep(modifiers: ModifierKey.command.rawValue, keyCode: 0x06)
      ])
    ),
    (
      "Key 2: Paste",
      2,
      KeyAssignment(steps: [
        MacroStep(modifiers: ModifierKey.command.rawValue, keyCode: 0x19)
      ])
    ),
    (
      "Key 3: Play/Pause",
      3,
      KeyAssignment(kind: .media, mediaAction: .playPause)
    ),
    (
      "Knob left: Volume Down",
      13,
      KeyAssignment(kind: .media, mediaAction: .volumeDown)
    ),
    (
      "Knob press: Mute",
      14,
      KeyAssignment(kind: .media, mediaAction: .mute)
    ),
    (
      "Knob right: Volume Up",
      15,
      KeyAssignment(kind: .media, mediaAction: .volumeUp)
    ),
  ]

  do {
    let status = transport.probe(checkAccess: true)
    guard status.state == .connected else {
      throw USBTransportError.unavailable(status.detail)
    }

    let info = try transport.configurationReportInfo()
    guard info.reportID == ProtocolEncoder.reportID,
      info.wireLength == ProtocolEncoder.reportLength
    else {
      throw USBTransportError.unavailable(
        "The connected device's HID report format does not match this configurator."
      )
    }

    print("Connected: \(status.detail)")
    print("Using V02.1.1 protocol; leaving firmware and lighting unchanged.")
    for item in preset {
      let reports = try encoder.reports(
        slot: item.slot,
        layer: 1,
        assignment: item.assignment,
        protocol: .vendorV0211
      )
      try transport.send(reports)
      print("saved: \(item.label)")
    }
    print("preset saved successfully")
    exit(EXIT_SUCCESS)
  } catch {
    fputs("preset failed: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
  }
}

if CommandLine.arguments.contains("--descriptor") {
  do {
    let info = try USBTransport().configurationReportInfo()
    print(
      "report id: \(info.reportID), payload: \(info.payloadLength) bytes, wire: \(info.wireLength) bytes"
    )
    exit(EXIT_SUCCESS)
  } catch {
    fputs("descriptor failed: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
  }
}

if CommandLine.arguments.contains("--self-test") {
  let encoder = ProtocolEncoder()
  let controlA = KeyAssignment(
    steps: [MacroStep(modifiers: ModifierKey.control.rawValue, keyCode: 0x04)]
  )

  func prefix(_ report: [UInt8], _ expected: [UInt8], _ label: String) {
    guard Array(report.prefix(expected.count)) == expected else {
      fputs("self-test failed: \(label)\n", stderr)
      exit(EXIT_FAILURE)
    }
    guard report.count == ProtocolEncoder.reportLength else {
      fputs("self-test failed: \(label) report length\n", stderr)
      exit(EXIT_FAILURE)
    }
  }

  do {
    let alternate = try encoder.reports(
      slot: 1, layer: 1, assignment: controlA, protocol: .alternate8890)
    guard alternate.count == 4 else { exit(EXIT_FAILURE) }
    prefix(alternate[0], [0x03, 0xFE, 0x01, 0x01, 0x01], "alternate start")
    prefix(alternate[1], [0x03, 0x01, 0x11, 0x01, 0x00, 0x00, 0x00], "alternate empty step")
    prefix(alternate[2], [0x03, 0x01, 0x11, 0x01, 0x01, 0x01, 0x04], "alternate key step")
    prefix(alternate[3], [0x03, 0xAA, 0xAA], "alternate commit")

    let vendor = try encoder.reports(
      slot: 1, layer: 1, assignment: controlA, protocol: .vendorV0211)
    guard vendor.count == 3 else { exit(EXIT_FAILURE) }
    prefix(vendor[0], [0x03, 0x01, 0x01, 0x01, 0x00, 0x01, 0x00], "vendor modifier step")
    prefix(vendor[1], [0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x04], "vendor key step")
    prefix(vendor[2], [0x03, 0xAA, 0xAA], "vendor commit")

    let layered = try encoder.reports(
      slot: 1, layer: 1, assignment: controlA, protocol: .layered8890)
    guard layered.count == 4 else { exit(EXIT_FAILURE) }
    prefix(layered[0], [0x03, 0xA1, 0x01], "layered layer select")
    prefix(layered[1], [0x03, 0x01, 0x11, 0x01, 0x00, 0x01, 0x00], "layered modifier step")
    prefix(layered[2], [0x03, 0x01, 0x11, 0x01, 0x01, 0x01, 0x04], "layered key step")
    prefix(layered[3], [0x03, 0xAA, 0xAA], "layered commit")

    let media = try encoder.reports(
      slot: 14,
      layer: 2,
      assignment: KeyAssignment(kind: .media, mediaAction: .volumeUp),
      protocol: .alternate8890
    )
    prefix(media[1], [0x03, 0x0E, 0x22, 0xE9, 0x00], "media usage")

    let mouse = try encoder.reports(
      slot: 2,
      layer: 3,
      assignment: KeyAssignment(kind: .mouse, mouseAction: .scrollDown),
      protocol: .alternate8890
    )
    prefix(mouse[1], [0x03, 0x02, 0x33, 0x00, 0x00, 0x00, 0xFF], "mouse wheel")

    let light = encoder.backlightReports(mode: 2, protocol: .vendorV0211)
    prefix(light[0], [0x03, 0xB0, 0x08, 0x02], "backlight")
    print("self-test passed: protocol vectors and 65-byte HID framing")
    exit(EXIT_SUCCESS)
  } catch {
    fputs("self-test failed: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
  }
}

let checkAccess = !CommandLine.arguments.contains("--probe-only")
let status = USBTransport().probe(checkAccess: checkAccess)
switch status.state {
case .connected:
  print("connected: \(status.detail)")
  exit(EXIT_SUCCESS)
case .disconnected:
  print("disconnected: \(status.detail)")
  exit(EXIT_FAILURE)
case .inaccessible:
  print("inaccessible: \(status.detail)")
  exit(EXIT_FAILURE)
}
