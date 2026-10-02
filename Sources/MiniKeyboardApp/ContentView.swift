import MiniKeyboardCore
import SwiftUI

struct ContentView: View {
  @StateObject private var model = AppModel()

  var body: some View {
    VStack(spacing: 0) {
      HeaderView(model: model)
      Divider()
      HStack(spacing: 0) {
        PadPanel(model: model)
          .frame(width: 390)
        Divider()
        InspectorPanel(model: model)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 980, idealWidth: 1080, minHeight: 680, idealHeight: 760)
    .background(Color(nsColor: .windowBackgroundColor))
    .task { model.refreshDevice() }
  }
}

private struct HeaderView: View {
  @ObservedObject var model: AppModel

  private var statusColor: Color {
    switch model.deviceStatus.state {
    case .connected: .green
    case .disconnected: .orange
    case .inaccessible: .red
    }
  }

  private var statusTitle: String {
    switch model.deviceStatus.state {
    case .connected: "Connected"
    case .disconnected: "Not connected"
    case .inaccessible: "Access needed"
    }
  }

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .fill(
            LinearGradient(
              colors: [Color.indigo, Color.blue],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        Image(systemName: "keyboard.badge.ellipsis")
          .font(.system(size: 25, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: 48, height: 48)

      VStack(alignment: .leading, spacing: 2) {
        Text("Mini Keyboard Studio")
          .font(.title2.weight(.semibold))
        Text("Native configurator · USB 1189:8890")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 8) {
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
        VStack(alignment: .leading, spacing: 0) {
          Text(statusTitle)
            .font(.callout.weight(.medium))
          Text(
            model.deviceStatus.state == .connected ? "Interface 1 · Endpoint 02" : "USB 1189:8890"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.quaternary.opacity(0.55), in: Capsule())

      Button {
        model.refreshDevice()
      } label: {
        Image(systemName: "arrow.clockwise")
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.borderless)
      .help("Refresh USB connection")
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 15)
  }
}

private struct PadPanel: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Label("Hardware", systemImage: "switch.2")
          .font(.headline)
        Picker("Layout", selection: $model.layout) {
          ForEach(HardwareLayout.allCases) { layout in
            Text(layout.title).tag(layout)
          }
        }
        .labelsHidden()
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Layer")
          .font(.headline)
        Picker("Layer", selection: $model.selectedLayer) {
          Text("1").tag(1)
          Text("2").tag(2)
          Text("3").tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(!model.keyboardProtocol.supportsLayers)
        if !model.keyboardProtocol.supportsLayers {
          Text("V02.1.1 stores one mapping per control.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      PadPreview(model: model)

      Spacer(minLength: 8)

      BacklightCard(model: model)

      Label {
        Text("Mappings are stored in the keypad. It keeps working after this app quits.")
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: "externaldrive.badge.checkmark")
          .foregroundStyle(.green)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(24)
    .background(Color(nsColor: .underPageBackgroundColor).opacity(0.65))
  }
}

private struct PadPreview: View {
  @ObservedObject var model: AppModel

  private var buttons: [ControlTarget] {
    model.targets.filter {
      if case .button = $0.kind { return true }
      return false
    }
  }

  private var knobs: [[ControlTarget]] {
    (1...model.layout.knobCount).map { index in
      model.targets.filter {
        if case .knob(let knobIndex, _) = $0.kind { return knobIndex == index }
        return false
      }
    }
  }

  var body: some View {
    VStack(spacing: 16) {
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: model.layout.columns),
        spacing: 10
      ) {
        ForEach(buttons) { target in
          PadKeyButton(target: target, model: model)
        }
      }

      HStack(spacing: 18) {
        ForEach(Array(knobs.enumerated()), id: \.offset) { index, targets in
          KnobControl(index: index + 1, targets: targets, model: model)
        }
      }
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 7)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(.quaternary, lineWidth: 1)
    )
  }
}

private struct PadKeyButton: View {
  let target: ControlTarget
  @ObservedObject var model: AppModel

  private var selected: Bool { model.selectedSlot == target.slot }

  var body: some View {
    Button {
      model.selectedSlot = target.slot
    } label: {
      VStack(spacing: 7) {
        Text(target.title)
          .font(.callout.weight(.semibold))
        Text(model.assignment(slot: target.slot).summary)
          .font(.caption2)
          .lineLimit(1)
          .foregroundStyle(selected ? .white.opacity(0.82) : .secondary)
      }
      .frame(maxWidth: .infinity, minHeight: 58)
      .padding(.horizontal, 6)
      .foregroundStyle(selected ? .white : .primary)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(selected ? Color.accentColor : Color(nsColor: .controlColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(selected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
      )
    }
    .buttonStyle(.plain)
  }
}

private struct KnobControl: View {
  let index: Int
  let targets: [ControlTarget]
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color(nsColor: .controlColor), Color.black.opacity(0.18)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay(Circle().stroke(.quaternary, lineWidth: 1))
          .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
        Capsule()
          .fill(.secondary)
          .frame(width: 3, height: 15)
          .offset(y: -16)
        Text("K\(index)")
          .font(.caption.weight(.bold))
          .offset(y: 8)
      }
      .frame(width: 76, height: 76)

      HStack(spacing: 5) {
        ForEach(targets) { target in
          let label: String = {
            if case .knob(_, let action) = target.kind {
              switch action {
              case .counterClockwise: return "↶"
              case .press: return "●"
              case .clockwise: return "↷"
              }
            }
            return ""
          }()
          Button(label) { model.selectedSlot = target.slot }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(model.selectedSlot == target.slot ? .accentColor : nil)
            .help(target.title)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

private struct BacklightCard: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Backlight", systemImage: "lightbulb.led")
          .font(.headline)
        Spacer()
        Picker("Backlight", selection: $model.backlightMode) {
          Text("Off").tag(UInt8(0))
          Text("Mode 1").tag(UInt8(1))
          Text("Mode 2").tag(UInt8(2))
        }
        .labelsHidden()
        .frame(width: 110)
      }
      Button("Save Backlight") { model.writeBacklight() }
        .buttonStyle(.bordered)
        .disabled(!model.isConnected || model.isWriting)
    }
    .padding(14)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct InspectorPanel: View {
  @ObservedObject var model: AppModel

  private var assignment: Binding<KeyAssignment> {
    Binding(
      get: { model.assignment() },
      set: { model.setAssignment($0) }
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              Text(model.selectedTarget.title)
                .font(.title.weight(.semibold))
              Text("Layer \(model.selectedLayer) · Device slot \(model.selectedSlot)")
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.assignment().summary)
              .font(.callout.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 11)
              .padding(.vertical, 6)
              .background(.quaternary.opacity(0.45), in: Capsule())
          }

          PresetStrip(model: model)
          AssignmentEditor(assignment: assignment)

          ProtocolCard(model: model)

          if let notice = model.notice {
            NoticeView(notice: notice)
              .transition(.opacity.combined(with: .move(edge: .bottom)))
          }
        }
        .padding(28)
      }

      Divider()
      HStack {
        Label("Writes only this control", systemImage: "checkmark.shield")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          model.writeSelectedControl()
        } label: {
          Label(
            model.isWriting ? "Saving…" : "Save to Keypad", systemImage: "square.and.arrow.down"
          )
          .frame(minWidth: 130)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.isConnected || model.isWriting)
        .keyboardShortcut(.return, modifiers: [.command])
      }
      .padding(.horizontal, 28)
      .padding(.vertical, 16)
      .background(.bar)
    }
  }
}

private struct PresetStrip: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("Quick presets")
        .font(.headline)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(Preset.allCases) { preset in
            Button(preset.title) { model.applyPreset(preset) }
              .buttonStyle(.bordered)
          }
        }
      }
    }
  }
}

private struct AssignmentEditor: View {
  @Binding var assignment: KeyAssignment

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Action")
          .font(.headline)
        Spacer()
        Picker("Action", selection: $assignment.kind) {
          ForEach(AssignmentKind.allCases) { kind in
            Text(kind.title).tag(kind)
          }
        }
        .labelsHidden()
        .frame(width: 190)
      }

      Group {
        switch assignment.kind {
        case .shortcut:
          MacroEditor(assignment: $assignment)
        case .media:
          LabeledContent("Media action") {
            Picker("Media action", selection: $assignment.mediaAction) {
              ForEach(MediaAction.allCases) { action in
                Text(action.title).tag(action)
              }
            }
            .labelsHidden()
            .frame(width: 220)
          }
        case .mouse:
          LabeledContent("Mouse action") {
            Picker("Mouse action", selection: $assignment.mouseAction) {
              ForEach(MouseAction.allCases) { action in
                Text(action.title).tag(action)
              }
            }
            .labelsHidden()
            .frame(width: 220)
          }
        case .disabled:
          Label("This control will do nothing.", systemImage: "nosign")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(18)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }
  }
}

private struct MacroEditor: View {
  @Binding var assignment: KeyAssignment

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(assignment.steps.indices), id: \.self) { index in
        MacroStepRow(
          number: index + 1,
          step: Binding(
            get: { assignment.steps[index] },
            set: { assignment.steps[index] = $0 }
          ),
          canDelete: assignment.steps.count > 1,
          delete: { assignment.steps.remove(at: index) }
        )
      }

      HStack {
        Button {
          assignment.steps.append(MacroStep())
        } label: {
          Label("Add Step", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(assignment.steps.count >= ProtocolEncoder.maximumMacroSteps)

        Spacer()
        Text("\(assignment.steps.count) / \(ProtocolEncoder.maximumMacroSteps) steps")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct MacroStepRow: View {
  let number: Int
  @Binding var step: MacroStep
  let canDelete: Bool
  let delete: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Text("\(number)")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 22)
        .background(.quaternary.opacity(0.6), in: Circle())

      HStack(spacing: 5) {
        ForEach(ModifierKey.allCases) { modifier in
          let active = step.modifiers & modifier.rawValue != 0
          Button(modifier.symbol) {
            if active {
              step.modifiers &= ~modifier.rawValue
            } else {
              step.modifiers |= modifier.rawValue
            }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .tint(active ? .accentColor : nil)
          .help(modifier.name)
        }
      }

      Picker("Key", selection: $step.keyCode) {
        ForEach(HIDKey.all) { key in
          Text(key.label).tag(key.code)
        }
      }
      .labelsHidden()
      .frame(maxWidth: .infinity)

      Button(role: .destructive, action: delete) {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless)
      .disabled(!canDelete)
      .opacity(canDelete ? 1 : 0.25)
    }
  }
}

private struct ProtocolCard: View {
  @ObservedObject var model: AppModel

  var body: some View {
    DisclosureGroup("Compatibility") {
      VStack(alignment: .leading, spacing: 10) {
        Picker("Protocol", selection: $model.keyboardProtocol) {
          ForEach(KeyboardProtocol.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)

        Text(model.keyboardProtocol.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(
          "This hardware has no configuration read-back. If a saved key does not change, try Layered 8890, then FE preamble, and save that control again."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(.top, 10)
    }
    .padding(14)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct NoticeView: View {
  let notice: AppModel.Notice

  private var color: Color {
    switch notice.kind {
    case .success: .green
    case .warning: .orange
    case .error: .red
    }
  }

  private var icon: String {
    switch notice.kind {
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .error: "xmark.octagon.fill"
    }
  }

  var body: some View {
    Label(notice.text, systemImage: icon)
      .font(.callout)
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
  }
}
