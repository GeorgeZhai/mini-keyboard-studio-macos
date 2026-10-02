import Foundation
import MiniKeyboardUSB

public struct DeviceStatus: Equatable, Sendable {
  public enum State: Equatable, Sendable {
    case disconnected
    case connected
    case inaccessible
  }

  public let state: State
  public let detail: String

  public init(state: State, detail: String) {
    self.state = state
    self.detail = detail
  }
}

public enum USBTransportError: LocalizedError {
  case unavailable(String)
  case writeFailed(String)

  public var errorDescription: String? {
    switch self {
    case .unavailable(let detail), .writeFailed(let detail):
      return detail
    }
  }
}

public struct USBTransport: Sendable {
  public static let vendorID: UInt16 = 0x1189
  public static let productID: UInt16 = 0x8890
  public static let reportLength = 65

  public init() {}

  public struct ReportInfo: Equatable, Sendable {
    public let reportID: UInt8
    public let payloadLength: Int

    public init(reportID: UInt8, payloadLength: Int) {
      self.reportID = reportID
      self.payloadLength = payloadLength
    }

    public var wireLength: Int { payloadLength + (reportID == 0 ? 0 : 1) }
  }

  private func decodedMessage(_ buffer: [CChar]) -> String {
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
  }

  public func probe(checkAccess: Bool = true) -> DeviceStatus {
    var message = [CChar](repeating: 0, count: 512)
    let result = MKUSBProbe(&message, message.count)
    let detail = decodedMessage(message)

    guard result == 1 else {
      return DeviceStatus(
        state: result == 0 ? .disconnected : .inaccessible,
        detail: detail
      )
    }

    guard checkAccess else {
      return DeviceStatus(state: .connected, detail: detail)
    }

    message = [CChar](repeating: 0, count: 512)
    let accessResult = MKUSBCheckAccess(&message, message.count)
    return DeviceStatus(
      state: accessResult == 0 ? .connected : .inaccessible,
      detail: decodedMessage(message)
    )
  }

  public func send(_ reports: [[UInt8]]) throws {
    guard !reports.isEmpty else { return }
    guard reports.allSatisfy({ $0.count == Self.reportLength }) else {
      throw USBTransportError.writeFailed("A configuration report had the wrong length.")
    }

    let info = try configurationReportInfo()
    guard info.wireLength == Self.reportLength else {
      throw USBTransportError.writeFailed(
        "The device expects \(info.wireLength)-byte reports, not \(Self.reportLength)-byte reports."
      )
    }
    guard reports.allSatisfy({ $0.first == info.reportID }) else {
      throw USBTransportError.writeFailed(
        "The device expects HID report ID \(info.reportID)."
      )
    }

    let flattened = reports.flatMap { $0 }
    var message = [CChar](repeating: 0, count: 512)
    let result = flattened.withUnsafeBytes { rawBuffer in
      MKUSBSendReports(
        rawBuffer.bindMemory(to: UInt8.self).baseAddress,
        reports.count,
        Self.reportLength,
        &message,
        message.count
      )
    }

    guard result == 0 else {
      throw USBTransportError.writeFailed(decodedMessage(message))
    }
  }

  public func configurationReportInfo() throws -> ReportInfo {
    var descriptor = [UInt8](repeating: 0, count: 512)
    var descriptorLength = 0
    var message = [CChar](repeating: 0, count: 512)
    let result = MKUSBGetReportDescriptor(
      &descriptor,
      descriptor.count,
      &descriptorLength,
      &message,
      message.count
    )
    guard result == 0 else {
      throw USBTransportError.unavailable(decodedMessage(message))
    }

    descriptor.removeSubrange(descriptorLength..<descriptor.count)
    var index = 0
    var reportID: UInt8 = 0
    var reportSize = 0
    var reportCount = 0
    while index < descriptor.count {
      let prefix = descriptor[index]
      if prefix == 0xFE {
        guard index + 1 < descriptor.count else { break }
        index += Int(descriptor[index + 1]) + 3
        continue
      }
      let sizeCode = Int(prefix & 0x03)
      let dataLength = sizeCode == 3 ? 4 : sizeCode
      guard index + dataLength < descriptor.count else { break }
      var value = 0
      if dataLength > 0 {
        for offset in 0..<dataLength {
          value |= Int(descriptor[index + 1 + offset]) << (8 * offset)
        }
      }
      switch prefix & 0xFC {
      case 0x84: reportID = UInt8(truncatingIfNeeded: value)
      case 0x74: reportSize = value
      case 0x94: reportCount = value
      case 0x90:
        let bytes = (reportSize * reportCount + 7) / 8
        return ReportInfo(reportID: reportID, payloadLength: bytes)
      default: break
      }
      index += dataLength + 1
    }
    throw USBTransportError.unavailable("The configuration interface has no HID output report.")
  }
}
