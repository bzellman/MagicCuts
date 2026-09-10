import Foundation
import Observation
@preconcurrency import CoreNFC

@MainActor @Observable
final class NFCInstrument: NSObject, @preconcurrency NFCTagReaderSessionDelegate {
    private(set) var active = false
    private(set) var status = "Ready to read a tag"
    private(set) var result: FieldCapture?
    private(set) var diagnostics: [CaptureDiagnostic] = []
    private(set) var failure: String?
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    @ObservationIgnored private var reader: NFCTagReaderSession?
    @ObservationIgnored private var readingTask: Task<Void, Never>?
    @ObservationIgnored private var began = ContinuousClock.now
    @ObservationIgnored private var completed = false
    @ObservationIgnored private var attemptDate = Date()

    func start() {
        stop(); result = nil; failure = nil; diagnostics = []; completed = false
        began = .now; attemptDate = .now
        guard NFCTagReaderSession.readingAvailable else {
            status = "NFC unavailable"; failure = "This device cannot start a Core NFC tag read. Saved NFC captures remain available."
            diagnostics.append(.init(step: "Availability", outcome: "Core NFC reader unavailable")); retainDiagnosticAttempt()
            return
        }
        began = .now; active = true; status = "Hold the top of the iPhone near one tag"
        // ISO 7816 polling is restricted to the NDEF application declared in Info.plist.
        let reader = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: .main)
        self.reader = reader; reader?.alertMessage = status; reader?.begin()
        diagnostics.append(.init(step: "Start reader", outcome: "ISO 14443 and ISO 15693 polling requested"))
    }
    func stop() {
        if active && !completed {
            status = "Read stopped"
            diagnostics.append(.init(step: "Reader ended", outcome: "Stopped by user or app lifecycle", duration: began.duration(to: .now).secondsValue))
            retainDiagnosticAttempt()
        }
        readingTask?.cancel(); readingTask = nil
        reader?.invalidate(); reader = nil; active = false
    }
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        guard reader === session else { return }
        diagnostics.append(.init(step: "Reader active", outcome: "Ready for a nearby tag", duration: began.duration(to: .now).secondsValue))
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        guard reader === session else { return }
        active = false; reader = nil; readingTask?.cancel(); readingTask = nil
        guard !completed else { return }
        let nfcError = error as? NFCReaderError
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled { status = "Read canceled" }
        else { status = "Read interrupted"; failure = error.localizedDescription }
        diagnostics.append(.init(step: "Reader ended", outcome: status, duration: began.duration(to: .now).secondsValue))
        retainDiagnosticAttempt()
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard reader === session, readingTask == nil else { return }
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "More than one tag detected. Keep one tag near the phone."
            diagnostics.append(.init(step: "Detect", outcome: "Multiple tags; move all but one away"))
            session.restartPolling(); return
        }
        diagnostics.append(.init(step: "Detect", outcome: "One tag found", duration: began.duration(to: .now).secondsValue))
        readingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let connectStart = ContinuousClock.now
                try await self.connect(session, to: tag)
                guard self.reader === session, !Task.isCancelled else { return }
                self.diagnostics.append(.init(step: "Connect", outcome: "Connected", duration: connectStart.duration(to: .now).secondsValue))
                let info = Self.tagInfo(tag)
                guard let info else { throw InstrumentError.unavailable("This tag protocol is not supported for NDEF inspection.") }
                let queryStart = ContinuousClock.now
                var read = NFCReadData(protocolName: info.name, identifier: info.identifier, manufacturer: info.manufacturer,
                                       status: "NDEF status unavailable", records: [])
                do {
                    let (status, capacity) = try await self.query(info.tag)
                    guard self.reader === session, !Task.isCancelled else { return }
                    read.capacity = status == .notSupported ? nil : capacity
                    switch status {
                    case .notSupported: read.status = "NDEF not supported"
                    case .readOnly: read.status = "Read-only"
                    case .readWrite: read.status = "Read/write reported"
                    @unknown default: read.status = "Unknown NDEF status"
                    }
                    self.diagnostics.append(.init(step: "Query NDEF", outcome: read.status, duration: queryStart.duration(to: .now).secondsValue))
                    if status != .notSupported {
                        let readStart = ContinuousClock.now
                        do {
                            let message = try await self.read(info.tag)
                            guard self.reader === session, !Task.isCancelled else { return }
                            guard message.length <= 1_048_576, message.records.count <= 512 else { throw InstrumentError.unavailable("The NDEF message exceeds the capture limit.") }
                            read.messageBytes = message.length
                            read.records = message.records
                            self.diagnostics.append(.init(step: "Read NDEF", outcome: "\(read.records.count) records, \(message.length) encoded bytes", duration: readStart.duration(to: .now).secondsValue))
                        } catch {
                            self.diagnostics.append(.init(step: "Read NDEF", outcome: "Contents unavailable: \(error.localizedDescription)", duration: readStart.duration(to: .now).secondsValue))
                        }
                    }
                } catch {
                    self.diagnostics.append(.init(step: "Query NDEF", outcome: "Status unavailable: \(error.localizedDescription)", duration: queryStart.duration(to: .now).secondsValue))
                }
                guard self.reader === session, !Task.isCancelled else { return }
                let date = Date()
                self.result = FieldCapture(title: "NFC tag", kind: .nfc, date: date, source: read.protocolName,
                    method: "Core NFC tag identity and NDEF read. Reported identifiers are not proof of authenticity. Capacity describes the NDEF allocation, not necessarily all tag memory. No write or lock commands are sent.",
                    diagnostics: self.diagnostics, nfc: read, placement: self.positionProvider?(date))
                self.completed = true; self.status = "Tag read complete"; self.active = false
                session.alertMessage = "Tag read complete"; session.invalidate()
            } catch {
                guard self.reader === session, !Task.isCancelled else { return }
                self.failure = error.localizedDescription; self.status = "Read interrupted"; self.active = false
                self.diagnostics.append(.init(step: "Read interrupted", outcome: error.localizedDescription))
                session.invalidate(errorMessage: "The tag could not be read. Keep it near the phone and try again.")
            }
        }
    }
    private func retainDiagnosticAttempt() {
        result = FieldCapture(title: "NFC scan attempt", kind: .nfc, date: attemptDate, source: "Core NFC",
            method: "App-observed reader attempt. Command durations include software and reader-session overhead; cancellation is not a tag failure.",
            diagnostics: Array(diagnostics.suffix(1000)), metadata: ["completion": status])
    }
    private func connect(_ session: NFCTagReaderSession, to tag: NFCTag) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.connect(to: tag) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
    private func query(_ tag: any NFCNDEFTag) async throws -> (NFCNDEFStatus, Int) {
        try await withCheckedThrowingContinuation { continuation in
            tag.queryNDEFStatus { status, capacity, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: (status, capacity)) }
            }
        }
    }
    private func read(_ tag: any NFCNDEFTag) async throws -> NFCMessageValue {
        try await withCheckedThrowingContinuation { continuation in
            tag.readNDEF { message, error in
                if let error { continuation.resume(throwing: error) }
                else if let message {
                    guard message.length <= 1_048_576, message.records.count <= 512 else {
                        continuation.resume(throwing: InstrumentError.unavailable("The NDEF message exceeds the capture limit.")); return
                    }
                    let records = message.records.enumerated().map { NFCRecordDecoder.record($0.element, index: $0.offset) }
                    continuation.resume(returning: NFCMessageValue(length: message.length, records: records))
                } else { continuation.resume(throwing: InstrumentError.unavailable("The tag returned no NDEF message.")) }
            }
        }
    }
    private static func tagInfo(_ tag: NFCTag) -> (tag: any NFCNDEFTag, name: String, identifier: Data?, manufacturer: String?)? {
        switch tag {
        case .miFare(let tag):
            let family: String
            switch tag.mifareFamily {
            case .ultralight: family = "MIFARE Ultralight"
            case .plus: family = "MIFARE Plus"
            case .desfire: family = "MIFARE DESFire"
            case .unknown: family = "ISO 14443 MIFARE-compatible"
            @unknown default: family = "ISO 14443"
            }
            return (tag, family, tag.identifier, nil)
        case .iso15693(let tag): return (tag, "ISO 15693", tag.identifier, "Reported IC manufacturer code \(tag.icManufacturerCode)")
        case .iso7816(let tag): return (tag, "ISO 7816 NDEF", tag.identifier, nil)
        case .feliCa(let tag): return (tag, "FeliCa", tag.currentIDm, nil)
        @unknown default: return nil
        }
    }
}

nonisolated private struct NFCMessageValue: Sendable { var length: Int; var records: [NFCRecordData] }

nonisolated enum NFCRecordDecoder {
    static func record(_ payload: NFCNDEFPayload, index: Int) -> NFCRecordData {
        var record = NFCRecordData(id: index, format: payload.typeNameFormat.rawValue, type: payload.type, identifier: payload.identifier, payload: payload.payload)
        if payload.typeNameFormat == .nfcWellKnown && payload.type == Data([0x54]) {
            record.decoded = decodeText(payload.payload)
        } else if payload.typeNameFormat == .nfcWellKnown && payload.type == Data([0x55]), let url = payload.wellKnownTypeURIPayload() {
            record.decoded = url.absoluteString; record.link = url
        } else if payload.typeNameFormat == .media,
                  String(data: payload.type, encoding: .utf8)?.lowercased().hasPrefix("text/") == true {
            record.decoded = String(data: payload.payload, encoding: .utf8)
        }
        return record
    }
    static func decodeText(_ payload: Data) -> String? {
        guard let status = payload.first, status & 0x40 == 0 else { return nil }
        let offset = 1 + Int(status & 0x3f)
        guard offset <= payload.count else { return nil }
        return String(data: payload.dropFirst(offset), encoding: status & 0x80 == 0 ? .utf8 : .utf16)
    }
}

extension Duration {
    nonisolated var secondsValue: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
