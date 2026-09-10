import Foundation
import UIKit

struct ReportFile: Identifiable {
    let title: String
    let symbol: String
    let url: URL
    var id: URL { url }
}

@MainActor
enum SessionReport {
    static func export(_ original: RecordedSession) throws -> [ReportFile] {
        var session = original
        // URL queries can contain access tokens. They are never needed to interpret a report.
        if let endpoint = session.source.endpoint, var components = URLComponents(string: endpoint) {
            components.query = nil; components.fragment = nil; components.user = nil; components.password = nil
            session.source.endpoint = components.url?.absoluteString
            session.source.id = session.source.endpoint ?? "endpoint"
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-Exports", isDirectory: true).appendingPathComponent(session.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = directory.appendingPathComponent("MagicCuts-session.json")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(session).write(to: json, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let csv = directory.appendingPathComponent("MagicCuts-readings.csv")
        try csvData(session).write(to: csv, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let pdf = directory.appendingPathComponent("MagicCuts-report.pdf")
        try pdfData(session).write(to: pdf, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return [ReportFile(title: "Share PDF report", symbol: "doc.richtext", url: pdf), ReportFile(title: "Share CSV readings", symbol: "tablecells", url: csv), ReportFile(title: "Share complete JSON", symbol: "curlybraces", url: json)]
    }

    nonisolated static func csvData(_ session: RecordedSession) -> Data {
        let auxiliary = Set(session.points.flatMap { $0.auxiliary.keys }).sorted()
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func field(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = [( ["timestamp_utc", "elapsed_seconds", "segment", "instrument", "value", "unit"] + auxiliary ).map(field).joined(separator: ",")]
        for point in session.points {
            let values = [formatter.string(from: point.date), String(point.elapsed), String(point.segment), session.kind.rawValue, String(point.value), session.kind.unit] + auxiliary.map { point.auxiliary[$0].map { String($0) } ?? "" }
            lines.append(values.map(field).joined(separator: ","))
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func pdfData(_ session: RecordedSession) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            var y: CGFloat = 0
            var page = 0
            let ink = UIColor(red: 0.05, green: 0.10, blue: 0.16, alpha: 1)
            let blue = UIColor(red: 0, green: 0.32, blue: 0.78, alpha: 1)
            func beginPage() {
                context.beginPage(); page += 1; y = 52
                let footer = "MagicCuts Pro  ·  Local measurement report                                      \(page)"
                footer.draw(at: CGPoint(x: 46, y: 755), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
            }
            func text(_ string: String, size: CGFloat = 11, weight: UIFont.Weight = .regular, color: UIColor? = nil, gap: CGFloat = 10) {
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color ?? ink]
                let rect = (string as NSString).boundingRect(with: CGSize(width: 520, height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                // Long notes are split into bounded paragraphs below, so every rendered block fits a page.
                if y + rect.height > 718 { beginPage() }
                (string as NSString).draw(in: CGRect(x: 46, y: y, width: 520, height: ceil(rect.height) + 2), withAttributes: attributes)
                y += ceil(rect.height) + gap
            }
            beginPage()
            text("MAGICCUTS PRO", size: 10, weight: .bold, color: blue, gap: 20)
            text(session.title, size: 26, weight: .bold, gap: 12)
            text("\(session.kind.title) · \(session.source.reportName)", size: 13, color: .darkGray)
            text(session.startedAt.formatted(date: .complete, time: .standard), size: 10, color: .darkGray, gap: 24)
            if let summary = session.summary {
                text("\(session.kind.formatted(summary.median)) \(session.kind.unit)", size: 38, weight: .semibold, color: blue, gap: 4)
                text("Session median · \(summary.count) readings · \(session.duration.formatted(.number.precision(.fractionLength(1)))) seconds", size: 10, color: .darkGray, gap: 20)
                if let reference = session.reference {
                    text("Compared with \(reference.name): \(session.kind.formatted(MeasurementMath.delta(summary.median, baseline: reference.summary.median, kind: session.kind), signed: true)) \(session.kind.deltaUnit) change in median", size: 12, weight: .semibold)
                }
                if y + 200 > 718 { beginPage() }
                let plot = CGRect(x: 75, y: y + 12, width: 468, height: 155)
                let range = session.kind.displayRange(values: session.points.map(\.value) + (session.reference?.points.map(\.value) ?? []))
                let duration = max(session.points.last?.elapsed ?? 1, session.reference?.points.last?.elapsed ?? 1, 0.001)
                let cg = context.cgContext
                cg.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor); cg.setLineWidth(0.5)
                for i in 0 ... 4 {
                    let lineY = plot.minY + CGFloat(i) * plot.height / 4
                    cg.move(to: CGPoint(x: plot.minX, y: lineY)); cg.addLine(to: CGPoint(x: plot.maxX, y: lineY)); cg.strokePath()
                    let value = range.upperBound - Double(i) * (range.upperBound - range.lowerBound) / 4
                    session.kind.formatted(value).draw(at: CGPoint(x: 46, y: lineY - 4), withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular), .foregroundColor: UIColor.darkGray])
                }
                func trace(_ points: [MeasurementPoint], dashed: Bool) {
                    let reduced = MeasurementMath.decimated(points, limit: 1000)
                    cg.saveGState(); cg.clip(to: plot); cg.setStrokeColor((dashed ? UIColor.darkGray : blue).cgColor)
                    cg.setLineWidth(dashed ? 1 : 1.6); cg.setLineDash(phase: 0, lengths: dashed ? [4, 3] : [])
                    var previous: MeasurementPoint?
                    for point in reduced {
                        let location = CGPoint(x: plot.minX + point.elapsed / duration * plot.width, y: plot.maxY - (point.value - range.lowerBound) / (range.upperBound - range.lowerBound) * plot.height)
                        if let previous, previous.segment == point.segment, !(session.kind == .heading && abs(previous.value - point.value) > 180) { cg.addLine(to: location) }
                        else { cg.move(to: location) }
                        previous = point
                    }
                    cg.strokePath(); cg.restoreGState()
                }
                if let reference = session.reference { trace(reference.points, dashed: true) }
                trace(session.points, dashed: false)
                y = plot.maxY + 14
                text("Elapsed seconds: 0 to \(duration.formatted(.number.precision(.fractionLength(1)))) · gaps are unobserved", size: 9, color: .darkGray)
                text("Middle 50%: \(session.kind.formatted(summary.q25)) to \(session.kind.formatted(summary.q75)) \(session.kind.unit). Range: \(session.kind.formatted(summary.minimum)) to \(session.kind.formatted(summary.maximum)) \(session.kind.unit).", size: 11, gap: 20)
            }
            text("Method", size: 14, weight: .bold)
            text(session.method)
            text("Ended: \(session.termination). Missing readings are not treated as zero. This report describes the observed session, not a guarantee of future results.")
            for key in session.metadata.keys.sorted().filter({ !["audioInput", "referenceFrame", "installationID"].contains($0) }) {
                text("\(MeasurementMetadata.label(key)): \(session.metadata[key] ?? "")", size: 9)
            }
            if !session.events.isEmpty {
                text("Session marks", size: 14, weight: .bold, gap: 16)
                for event in session.events {
                    // Bound arbitrary user text so a single note cannot overflow the PDF page.
                    let chars = Array(event.text)
                    for start in stride(from: 0, to: chars.count, by: 800) {
                        let piece = String(chars[start ..< min(start + 800, chars.count)])
                        text("\(event.elapsed.formatted(.number.precision(.fractionLength(1))))s · \(piece)")
                    }
                }
            }
        }
    }
}

nonisolated enum MeasurementMetadata {
    static func label(_ key: String) -> String {
        switch key {
        case "audioInputName": "Microphone"
        case "audioSampleRate": "Audio sample rate (Hz)"
        case "audioWindow": "Audio analysis"
        case "spectrumAxis": "Spectrum axis"
        case "sampleRateHz": "Observed motion sample rate (Hz)"
        case "fieldCalibration": "Magnetic calibration"
        case "locationAccuracy": "Location accuracy"
        case "networkPath": "Connection path"
        case "requestMethod": "Request method"
        case "completedRequests": "Successful requests"
        case "failedRequests": "Failed requests"
        case "powerState": "Power source"
        case "thermalState": "Thermal state"
        case "lowPowerMode": "Low Power Mode"
        case "fixture": "Sample data"
        default: key
        }
    }
}
