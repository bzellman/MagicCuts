import Foundation
import RoomPlan
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum RoomExportFormat: String, CaseIterable, Identifiable, Sendable {
    case archive, observedMesh, recognizedModel, measurements
    var id: String { rawValue }
    var title: String {
        switch self {
        case .archive: "Room archive · JSON"
        case .observedMesh: "Observed mesh · OBJ"
        case .recognizedModel: "Recognized room · USDZ"
        case .measurements: "Measurements · CSV"
        }
    }
    var explanation: String {
        switch self {
        case .archive: "This revision's full geometry, dimensions, recognition data, orientation map, and reference photo where available. Import it into Rooms to retain those capabilities. Other revisions and separately saved readings are not included."
        case .observedMesh: "Original observed vertices and triangles in meters, in this revision's coordinate frame. No camera photo, orientation map, measurements, or tag contents. The OBJ header records the revision and coordinate frame."
        case .recognizedModel: "A viewable RoomPlan model of recognized walls and objects. This is simplified geometry; it does not contain the detailed surface mesh or orientation map."
        case .measurements: "Selected dimensions and supported area/volume estimates, with units, methods, and revision identifiers. Separately saved readings have their own exports."
        }
    }
}

nonisolated enum FieldExport {
    static let maximumArchiveBytes = 384 * 1024 * 1024
    @concurrent static func room(_ room: RoomRevision) async throws -> URL { try write(room, name: "Room-\(room.id).json") }
    @concurrent static func capture(_ capture: FieldCapture) async throws -> URL { try write(capture, name: "Capture-\(capture.id).json") }
    @concurrent static func exportRoom(_ room: RoomRevision, format: RoomExportFormat) async throws -> URL {
        guard room.isValid else { throw InstrumentError.storage("This room has invalid geometry and could not be exported.") }
        switch format {
        case .archive: return try await self.room(room)
        case .recognizedModel:
            guard let data = room.semanticData else { throw InstrumentError.unavailable("This revision has no recognized RoomPlan model. Export its observed mesh instead.") }
            let model = try JSONDecoder().decode(CapturedRoom.self, from: data)
            let url = try directory().appendingPathComponent("Recognized-Room-\(room.id).usdz")
            try model.export(to: url, exportOptions: .mesh)
            return url
        case .observedMesh:
            let url = try directory().appendingPathComponent("Observed-Room-\(room.id)-meters.obj")
            // Write incrementally so a full-size room does not need a second giant in-memory string.
            let temporary = try directory().appendingPathComponent(UUID().uuidString + ".obj")
            guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else { throw InstrumentError.storage("The export file could not be created.") }
            defer { try? FileManager.default.removeItem(at: temporary) }
            let handle = try FileHandle(forWritingTo: temporary)
            do {
                try handle.write(contentsOf: Data("# MagicCuts observed mesh\n# Units: meters; up: +Y\n# Room: \(room.roomID)\n# Revision: \(room.id)\n# Coordinate frame: \(room.coordinateFrameID)\n# Observed: \(room.endedAt.ISO8601Format())\n# Missing surfaces are unobserved; this is not a closed-volume guarantee.\n".utf8))
                var base = 1
                for mesh in room.meshes {
                    try Task.checkCancellation()
                    try handle.write(contentsOf: Data("o patch_\(mesh.id.uuidString.replacingOccurrences(of: "-", with: "_"))\n".utf8))
                    var chunk = ""
                    for (index, vertex) in mesh.vertices.enumerated() {
                        let point = mesh.transform.worldPoint(vertex)
                        chunk += "v \(point.x) \(point.y) \(point.z)\n"
                        if index.isMultiple(of: 4096) { try handle.write(contentsOf: Data(chunk.utf8)); chunk = "" }
                    }
                    try handle.write(contentsOf: Data(chunk.utf8)); chunk = ""
                    for i in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
                        chunk += "f \(Int(mesh.triangleIndices[i]) + base) \(Int(mesh.triangleIndices[i + 1]) + base) \(Int(mesh.triangleIndices[i + 2]) + base)\n"
                        if i.isMultiple(of: 4095) { try handle.write(contentsOf: Data(chunk.utf8)); chunk = "" }
                    }
                    try handle.write(contentsOf: Data(chunk.utf8)); base += mesh.vertices.count
                }
                try handle.close()
            } catch { try? handle.close(); throw error }
            if FileManager.default.fileExists(atPath: url.path) { _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary) }
            else { try FileManager.default.moveItem(at: temporary, to: url) }
            return url
        case .measurements:
            var rows = [["room_id", "revision_id", "coordinate_frame_id", "observed_at", "measurement", "value", "unit", "method", "start_x_m", "start_y_m", "start_z_m", "end_x_m", "end_y_m", "end_z_m"]]
            let prefix = [room.roomID.uuidString, room.id.uuidString, room.coordinateFrameID.uuidString, room.endedAt.ISO8601Format()]
            for dimension in room.dimensions {
                rows.append(prefix + [dimension.title, String(dimension.meters), "m", dimension.method,
                    String(dimension.start.x), String(dimension.start.y), String(dimension.start.z), String(dimension.end.x), String(dimension.end.y), String(dimension.end.z)])
            }
            if let area = room.floorArea { rows.append(prefix + ["Recognized floor area", String(area), "m2", "Closed recognized floor polygon estimate"] + Array(repeating: "", count: 6)) }
            if let volume = room.estimatedVolume { rows.append(prefix + ["Height-extruded volume", String(volume), "m3", "Floor estimate multiplied by consistent wall height; excludes ceiling shape"] + Array(repeating: "", count: 6)) }
            return try writeCSV(rows, name: "Room-Measurements-\(room.id).csv")
        }
    }
    @concurrent static func captureCSV(_ capture: FieldCapture) async throws -> URL {
        var rows = [["capture_id", "observed_at", "source", "measurement", "value", "unit", "method", "room_id", "revision_id", "frame_id", "x_m", "y_m", "z_m", "placement_method"]]
        func row(_ date: Date, _ title: String, _ value: String, _ unit: String, _ method: String, _ placement: RoomPlacement?) -> [String] {
            [capture.id.uuidString, date.ISO8601Format(), capture.source, title, value, unit, method,
             placement?.roomID.uuidString ?? "", placement?.revisionID.uuidString ?? "", placement?.coordinateFrameID.uuidString ?? "",
             placement.map { String($0.pose.position.x) } ?? "", placement.map { String($0.pose.position.y) } ?? "", placement.map { String($0.pose.position.z) } ?? "", placement?.method.rawValue ?? ""]
        }
        for metric in capture.metrics { rows.append(row(capture.date, metric.title, String(metric.value), metric.unit, metric.qualifier, capture.placement)) }
        for probe in capture.probes { rows.append(row(probe.date, "Request response time", probe.succeeded ? String(probe.durationMS) : "", "ms", probe.error ?? "Successful HTTP response", probe.placement)) }
        for sample in capture.samples {
            if sample.values.isEmpty { rows.append(row(sample.date, "Missing sample", "", "", sample.detail, sample.placement)) }
            for key in sample.values.keys.sorted() { rows.append(row(sample.date, key, String(sample.values[key]!), capture.metrics.first(where: { $0.id == key })?.unit ?? "See capture JSON", sample.detail, sample.placement)) }
        }
        return try writeCSV(rows, name: "Capture-\(capture.id).csv")
    }
    @concurrent static func importRoom(_ url: URL) async throws -> RoomRevision {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size > 0, size <= maximumArchiveBytes else { throw InstrumentError.storage("Choose a MagicCuts room JSON archive smaller than 384 MiB.") }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumArchiveBytes else { throw InstrumentError.storage("The room archive exceeds the import size limit.") }
        let room = try JSONDecoder().decode(RoomRevision.self, from: data)
        guard room.isValid else { throw InstrumentError.storage("The archive contains unsupported or invalid room geometry. No saved room was changed.") }
        return room
    }
    private static func writeCSV(_ rows: [[String]], name: String) throws -> URL {
        func escape(_ value: String) -> String {
            let first = value.trimmingCharacters(in: .whitespaces).first
            let safe = first.map { "=+@-".contains($0) && Double(value) == nil } == true ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let url = try directory().appendingPathComponent(name)
        try (rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    private static func write<T: Encodable>(_ value: T, name: String) throws -> URL {
        let url = try directory().appendingPathComponent(name)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
        return url
    }
    private static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-Field-Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

struct RoomExportView: View {
    let room: RoomRevision
    @State private var format: RoomExportFormat = .archive
    @State private var url: URL?
    @State private var failure: String?
    @State private var working = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $format) {
                        ForEach(RoomExportFormat.allCases) { format in
                            if format != .recognizedModel || room.semanticData != nil { Text(format.title).tag(format) }
                        }
                    }.disabled(working)
                    Text(format.explanation).font(.callout)
                    if room.semanticData == nil { Text("A recognized USDZ model is unavailable for this revision. Its observed mesh can still be exported.").font(.caption).foregroundStyle(ProTheme.secondary) }
                }
                Section {
                    Button("Prepare export") { Task {
                        working = true; url = nil; failure = nil; defer { working = false }
                        do { url = try await FieldExport.exportRoom(room, format: format) } catch { failure = error.localizedDescription }
                    } }.disabled(working).accessibilityIdentifier("room.export.prepare")
                    if working { ProgressView("Preparing export…") }
                    if let url { ShareLink(item: url) { Label("Share \(format.title)", systemImage: "square.and.arrow.up") }.accessibilityIdentifier("room.export.share") }
                }
                if let failure { InlineFailure(message: failure) }
            }.navigationTitle("Export room").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(working) } }
            .onChange(of: format) { _, _ in url = nil; failure = nil }
        }.interactiveDismissDisabled(working)
    }
}
