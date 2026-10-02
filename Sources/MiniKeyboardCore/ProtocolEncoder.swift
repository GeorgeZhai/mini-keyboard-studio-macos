import Foundation

public enum ProtocolEncodingError: LocalizedError, Equatable {
  case invalidLayer
  case invalidSlot
  case macroTooLong
  case emptyMacro

  public var errorDescription: String? {
    switch self {
    case .invalidLayer: "Layer must be between 1 and 3."
    case .invalidSlot: "That control is outside the supported slot range."
    case .macroTooLong: "This firmware supports at most 5 shortcut steps per control."
    case .emptyMacro: "Add at least one shortcut step."
    }
  }
}

public struct ProtocolEncoder: Sendable {
  public static let reportID: UInt8 = 0x03
  // The descriptor declares report ID 3 plus a 64-byte payload.
  public static let reportLength = 65
  public static let maximumMacroSteps = 5

  public init() {}

  public func reports(
    slot: UInt8,
    layer: Int,
    assignment: KeyAssignment,
    protocol selectedProtocol: KeyboardProtocol
  ) throws -> [[UInt8]] {
    guard (1...3).contains(layer) else {
      throw ProtocolEncodingError.invalidLayer
    }
    guard (1...18).contains(Int(slot)) else {
      throw ProtocolEncodingError.invalidSlot
    }

    switch selectedProtocol {
    case .vendorV0211:
      return try vendorReports(slot: slot, layer: UInt8(layer), assignment: assignment)
    case .layered8890:
      return try layeredReports(slot: slot, layer: UInt8(layer), assignment: assignment)
    case .alternate8890:
      return try alternateReports(slot: slot, layer: UInt8(layer), assignment: assignment)
    }
  }

  public func backlightReports(mode: UInt8, protocol selectedProtocol: KeyboardProtocol)
    -> [[UInt8]]
  {
    let type: UInt8 = selectedProtocol == .vendorV0211 ? 0x08 : 0x18
    return [
      report([0xB0, type, min(mode, 2)]),
      report([0xAA, 0xA1]),
    ]
  }

  private func vendorReports(
    slot: UInt8,
    layer: UInt8,
    assignment: KeyAssignment
  ) throws -> [[UInt8]] {
    var output: [[UInt8]] = []
    let effective = effectiveAssignment(assignment)

    switch effective.kind {
    case .shortcut, .disabled:
      let steps = effective.steps
      guard !steps.isEmpty else { throw ProtocolEncodingError.emptyMacro }
      guard steps.count <= Self.maximumMacroSteps else {
        throw ProtocolEncodingError.macroTooLong
      }
      let count = UInt8(steps.count)
      let leadingModifier = steps.first?.modifiers ?? 0
      output.append(
        report([
          slot, 0x01, count, 0x00, leadingModifier, 0x00, 0x00, 0x00,
        ]))
      for (offset, step) in steps.enumerated() {
        output.append(
          report([
            slot, 0x01, count, UInt8(offset + 1),
            step.modifiers, step.keyCode, 0x00, 0x00,
          ]))
      }
    case .media:
      let usage = effective.mediaAction.usage
      output.append(
        report([
          slot, 0x02, UInt8(usage & 0xFF), UInt8(usage >> 8),
          0, 0, 0, 0,
        ]))
    case .mouse:
      let mouse = effective.mouseAction.payload
      output.append(
        report([
          slot, 0x03, mouse.button, mouse.x, mouse.y,
          mouse.wheel, mouse.modifier, 0,
        ]))
    }

    output.append(report([0xAA, 0xAA]))
    return output
  }

  private func layeredReports(
    slot: UInt8,
    layer: UInt8,
    assignment: KeyAssignment
  ) throws -> [[UInt8]] {
    var output = [report([0xA1, layer])]
    let effective = effectiveAssignment(assignment)
    let typeByte = { (type: UInt8) in (layer << 4) | type }

    switch effective.kind {
    case .shortcut, .disabled:
      let steps = effective.steps
      guard !steps.isEmpty else { throw ProtocolEncodingError.emptyMacro }
      guard steps.count <= Self.maximumMacroSteps else {
        throw ProtocolEncodingError.macroTooLong
      }
      let count = UInt8(steps.count)
      let leadingModifier = steps.first?.modifiers ?? 0
      output.append(
        report([
          slot, typeByte(0x01), count, 0x00, leadingModifier, 0x00, 0x00, 0x00,
        ]))
      for (offset, step) in steps.enumerated() {
        output.append(
          report([
            slot, typeByte(0x01), count, UInt8(offset + 1),
            step.modifiers, step.keyCode, 0x00, 0x00,
          ]))
      }
    case .media:
      let usage = effective.mediaAction.usage
      output.append(
        report([
          slot, typeByte(0x02), UInt8(usage & 0xFF), UInt8(usage >> 8),
          0, 0, 0, 0,
        ]))
    case .mouse:
      let mouse = effective.mouseAction.payload
      output.append(
        report([
          slot, typeByte(0x03), mouse.button, mouse.x, mouse.y,
          mouse.wheel, mouse.modifier, 0,
        ]))
    }

    output.append(report([0xAA, 0xAA]))
    return output
  }

  private func alternateReports(
    slot: UInt8,
    layer: UInt8,
    assignment: KeyAssignment
  ) throws -> [[UInt8]] {
    var output = [report([0xFE, layer, 0x01, 0x01, 0, 0, 0, 0])]
    let effective = effectiveAssignment(assignment)
    let typeByte = { (type: UInt8) in (layer << 4) | type }

    switch effective.kind {
    case .shortcut, .disabled:
      let steps = effective.steps
      guard !steps.isEmpty else { throw ProtocolEncodingError.emptyMacro }
      guard steps.count <= Self.maximumMacroSteps else {
        throw ProtocolEncodingError.macroTooLong
      }
      let count = UInt8(steps.count)
      output.append(
        report([
          slot, typeByte(0x01), count, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]))
      for (offset, step) in steps.enumerated() {
        output.append(
          report([
            slot, typeByte(0x01), count, UInt8(offset + 1),
            step.modifiers, step.keyCode, 0x00, 0x00,
          ]))
      }
    case .media:
      let usage = effective.mediaAction.usage
      output.append(
        report([
          slot, typeByte(0x02), UInt8(usage & 0xFF), UInt8(usage >> 8),
          0, 0, 0, 0,
        ]))
    case .mouse:
      let mouse = effective.mouseAction.payload
      output.append(
        report([
          slot, typeByte(0x03), mouse.button, mouse.x, mouse.y,
          mouse.wheel, mouse.modifier, 0,
        ]))
    }

    output.append(report([0xAA, 0xAA]))
    return output
  }

  private func effectiveAssignment(_ assignment: KeyAssignment) -> KeyAssignment {
    guard assignment.kind == .disabled else { return assignment }
    return KeyAssignment(
      kind: .disabled,
      steps: [MacroStep(modifiers: 0, keyCode: 0)]
    )
  }

  private func report(_ payload: [UInt8]) -> [UInt8] {
    precondition(payload.count <= Self.reportLength - 1)
    var bytes = [UInt8](repeating: 0, count: Self.reportLength)
    bytes[0] = Self.reportID
    bytes.replaceSubrange(1..<(payload.count + 1), with: payload)
    return bytes
  }
}
