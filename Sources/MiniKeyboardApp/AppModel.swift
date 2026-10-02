import Combine
import Foundation
import MiniKeyboardCore

@MainActor
final class AppModel: ObservableObject {
  struct Notice: Identifiable, Equatable {
    enum Kind { case success, warning, error }
    let id = UUID()
    let kind: Kind
    let text: String
  }

  private struct SavedDraft: Codable {
    var layout: HardwareLayout
    var keyboardProtocol: KeyboardProtocol
    var assignments: [String: KeyAssignment]
    var backlightMode: UInt8
  }

  @Published var deviceStatus = DeviceStatus(
    state: .disconnected,
    detail: "Looking for the keyboard…"
  )
  @Published var layout: HardwareLayout = .threeKeysOneKnob {
    didSet {
      normalizeSelection()
      persist()
    }
  }
  @Published var keyboardProtocol: KeyboardProtocol = .vendorV0211 {
    didSet {
      if !keyboardProtocol.supportsLayers {
        selectedLayer = 1
      }
      persist()
    }
  }
  @Published var selectedLayer = 1
  @Published var selectedSlot: UInt8 = 1
  @Published var assignments: [String: KeyAssignment] = [:] {
    didSet { persist() }
  }
  @Published var backlightMode: UInt8 = 1 {
    didSet { persist() }
  }
  @Published var notice: Notice?
  @Published var isWriting = false

  let transport = USBTransport()
  let encoder = ProtocolEncoder()

  var targets: [ControlTarget] { ControlTarget.targets(for: layout) }

  var selectedTarget: ControlTarget {
    targets.first(where: { $0.slot == selectedSlot }) ?? targets[0]
  }

  var isConnected: Bool { deviceStatus.state == .connected }

  init() {
    if let saved = loadDraft() {
      layout = saved.layout
      keyboardProtocol = saved.keyboardProtocol
      assignments = saved.assignments
      backlightMode = saved.backlightMode
    } else {
      assignments = Self.starterAssignments()
    }
    normalizeSelection()
  }

  func refreshDevice() {
    deviceStatus = transport.probe(checkAccess: true)
    switch deviceStatus.state {
    case .connected:
      notice = nil
    case .disconnected:
      notice = Notice(kind: .warning, text: "Connect the keypad by USB, then refresh.")
    case .inaccessible:
      notice = Notice(kind: .error, text: deviceStatus.detail)
    }
  }

  func assignment(layer: Int? = nil, slot: UInt8? = nil) -> KeyAssignment {
    assignments[key(layer: layer ?? selectedLayer, slot: slot ?? selectedSlot)]
      ?? KeyAssignment(kind: .disabled)
  }

  func setAssignment(_ assignment: KeyAssignment, layer: Int? = nil, slot: UInt8? = nil) {
    assignments[key(layer: layer ?? selectedLayer, slot: slot ?? selectedSlot)] = assignment
  }

  func applyPreset(_ preset: Preset) {
    setAssignment(preset.assignment)
  }

  func writeAllControls() {
    guard isConnected else {
      notice = Notice(kind: .error, text: "The configuration interface is not connected.")
      return
    }

    isWriting = true
    defer { isWriting = false }
    do {
      let controls = targets.map { target in
        (slot: target.slot, assignment: assignment(slot: target.slot))
      }
      let reports = try encoder.reports(
        for: controls,
        layer: selectedLayer,
        protocol: keyboardProtocol
      )
      try transport.send(reports)
      let layerDescription =
        keyboardProtocol.supportsLayers
        ? " on Layer \(selectedLayer)"
        : ""
      notice = Notice(
        kind: .success,
        text: "Saved all \(targets.count) controls\(layerDescription) to the keypad."
      )
    } catch {
      notice = Notice(kind: .error, text: error.localizedDescription)
      deviceStatus = transport.probe(checkAccess: false)
    }
  }

  func writeBacklight() {
    guard isConnected else {
      notice = Notice(kind: .error, text: "The configuration interface is not connected.")
      return
    }

    isWriting = true
    defer { isWriting = false }
    do {
      try transport.send(
        encoder.backlightReports(
          mode: backlightMode,
          protocol: keyboardProtocol
        ))
      notice = Notice(kind: .success, text: "Saved the backlight mode to the keypad.")
    } catch {
      notice = Notice(kind: .error, text: error.localizedDescription)
    }
  }

  private func normalizeSelection() {
    guard !targets.contains(where: { $0.slot == selectedSlot }) else { return }
    selectedSlot = targets.first?.slot ?? 1
  }

  private func key(layer: Int, slot: UInt8) -> String {
    "layer-\(layer)-slot-\(slot)"
  }

  private static let draftKey = "MiniKeyboard.savedDraft.v1"

  private func loadDraft() -> SavedDraft? {
    guard let data = UserDefaults.standard.data(forKey: Self.draftKey) else { return nil }
    return try? JSONDecoder().decode(SavedDraft.self, from: data)
  }

  private func persist() {
    let saved = SavedDraft(
      layout: layout,
      keyboardProtocol: keyboardProtocol,
      assignments: assignments,
      backlightMode: backlightMode
    )
    if let data = try? JSONEncoder().encode(saved) {
      UserDefaults.standard.set(data, forKey: Self.draftKey)
    }
  }

  private static func starterAssignments() -> [String: KeyAssignment] {
    var result: [String: KeyAssignment] = [:]
    result["layer-1-slot-1"] = Preset.copy.assignment
    result["layer-1-slot-2"] = Preset.paste.assignment
    result["layer-1-slot-3"] = Preset.playPause.assignment
    result["layer-1-slot-13"] = Preset.volumeDown.assignment
    result["layer-1-slot-14"] = KeyAssignment(kind: .media, mediaAction: .mute)
    result["layer-1-slot-15"] = Preset.volumeUp.assignment
    return result
  }
}
