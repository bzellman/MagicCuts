import SwiftUI
import Charts
import simd

struct FieldCaptureDetailView: View {
    let id: UUID
    @Bindable var library: ProLibrary
    @State private var capture: FieldCapture?
    @State private var failure: String?
    @State private var placing = false
    @State private var exportURL: URL?
    @State private var comparison: FieldCapture?
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let capture {
                    FieldCaptureEvidence(capture: capture)
                    if let placement = capture.placement {
                        NavigationLink { RoomDetailView(id: placement.revisionID, library: library) } label: {
                            Label("View location in room", systemImage: "mappin.and.ellipse")
                        }.frame(minHeight: 44)
                        Text("\(placement.method.title) · position recorded \(placement.observedAt.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundStyle(ProTheme.secondary)
                        if !placement.note.isEmpty { Text(placement.note).font(.callout) }
                    }
                    Button(capture.placement == nil ? "Place in a room" : "Edit placement manually") { placing = true }.frame(minHeight: 44)
                        .disabled(library.index.roomRevisions.isEmpty)
                    Menu("Compare with saved capture") {
                        ForEach(library.index.fieldCaptures.filter { $0.kind == capture.kind && $0.id != capture.id }) { other in
                            Button("\(other.title) · \(other.date.formatted(date: .abbreviated, time: .shortened))") { Task {
                                do { comparison = try await library.archive.loadFieldCapture(other.id) }
                                catch { failure = error.localizedDescription }
                            } }
                        }
                    }.frame(minHeight: 44)
                    if let comparison { FieldCaptureComparison(current: capture, earlier: comparison) }
                    if let exportURL { ShareLink(item: exportURL) { Label("Share capture export", systemImage: "square.and.arrow.up") }.frame(minHeight: 44) }
                } else if failure == nil { ProgressView("Opening capture…") }
                if let failure { InlineFailure(message: failure) }
            }.padding(22).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.background(MC.canvas).scrollEdgeEffectStyle(.hard, for: .all).navigationTitle(capture?.title ?? "Capture").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Menu {
                Button("Export full capture JSON", systemImage: "square.and.arrow.up") { Task {
                    guard let capture else { return }
                    do { exportURL = try await FieldExport.capture(capture) } catch { failure = error.localizedDescription }
                } }
                Button("Export measurements CSV", systemImage: "tablecells") { Task {
                    guard let capture else { return }
                    do { exportURL = try await FieldExport.captureCSV(capture) } catch { failure = error.localizedDescription }
                } }
                Button("Delete capture", systemImage: "trash", role: .destructive) { deleting = true }
            } label: { Label("Capture actions", systemImage: "ellipsis.circle") } }
        }
        .task(id: id) { do { capture = try await library.archive.loadFieldCapture(id) } catch { failure = error.localizedDescription } }
        .sheet(isPresented: $placing) { RoomPlacementView(library: library, original: capture?.placement) { placement in
            guard var value = capture else { return }; value.placement = placement
            do { try await library.save(value); capture = value }
            catch { throw error }
        } }
        .confirmationDialog("Delete this capture?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete capture", role: .destructive) { Task {
                do { _ = try await library.archive.deleteFieldCapture(id); await library.reload(); dismiss() }
                catch { failure = error.localizedDescription }
            } }
        }
    }
}

struct FieldCaptureSaveView: View {
    let capture: FieldCapture
    @Bindable var library: ProLibrary
    @State private var title = ""
    @State private var note = ""
    @State private var placement: RoomPlacement?
    @State private var placing = false
    @State private var working = false
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Capture") {
                    TextField("Title", text: $title).accessibilityIdentifier("capture.title")
                    TextField("What did you notice?", text: $note, axis: .vertical).lineLimit(2...5)
                    Text(capture.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(ProTheme.secondary)
                }
                Section("Location") {
                    if let placement { Label(placement.method.title, systemImage: "mappin.and.ellipse") }
                    else { Text("No room position recorded").foregroundStyle(ProTheme.secondary) }
                    Button(placement == nil ? "Place in a room" : "Edit placement manually") { placing = true }.disabled(library.index.roomRevisions.isEmpty)
                    if placement != nil { Button("Remove location", role: .destructive) { placement = nil } }
                    Text("A tracked position belongs to the moment the reading was captured. A later manual placement is labeled separately.").font(.caption).foregroundStyle(ProTheme.secondary)
                }
                Section { FieldCaptureEvidence(capture: capture) }
                if let failure { InlineFailure(message: failure) }
            }.navigationTitle("Save capture").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task {
                    working = true; defer { working = false }
                    var value = capture; value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    value.placement = placement; value.metadata["note"] = note
                    do { try await library.save(value); dismiss() } catch { failure = error.localizedDescription }
                } }.disabled(working || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("capture.save") }
            }.onAppear { title = capture.title; placement = capture.placement; note = capture.metadata["note"] ?? "" }
            .sheet(isPresented: $placing) { RoomPlacementView(library: library, original: placement) { placement = $0 } }
            .interactiveDismissDisabled(working)
        }
    }
}

struct RoomPlacementView: View {
    @Bindable var library: ProLibrary
    let original: RoomPlacement?
    let onPlace: (RoomPlacement) async throws -> Void
    @State private var revisionID: UUID?
    @State private var room: RoomRevision?
    @State private var x = 0.0
    @State private var y = 1.2
    @State private var z = 0.0
    @State private var heading = 0.0
    @State private var note = ""
    @State private var failure: String?
    @State private var working = false
    @Environment(\.dismiss) private var dismiss
    private var pose: SpatialTransform {
        var matrix = simd_float4x4(simd_quatf(angle: -Float(heading * .pi / 180), axis: SIMD3(0, 1, 0)))
        matrix.columns.3 = SIMD4(Float(x), Float(y), Float(z), 1)
        return SpatialTransform(matrix)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Room revision", selection: $revisionID) {
                        Text("Choose a room").tag(Optional<UUID>.none)
                        ForEach(library.index.roomRevisions) { revision in
                            Text("\(revision.roomName) · \(revision.date.formatted(date: .abbreviated, time: .shortened))").tag(Optional(revision.id))
                        }
                    }
                    Text("Place manually").font(.headline)
                    Text("Tap the plan or enter coordinates in this room's local frame. This does not establish camera tracking.").font(.callout).foregroundStyle(ProTheme.secondary)
                }
                if let room {
                    Section {
                        RoomPlanCanvas(room: room, pose: pose, onPoint: { point in x = Double(point.x); z = Double(point.z) }).frame(height: 260)
                        coordinate("X position (m)", value: $x); coordinate("Z position (m)", value: $z)
                        coordinate("Height in room frame (m)", value: $y)
                        LabeledContent("Orientation", value: "\(Int(heading))°")
                        Slider(value: $heading, in: -180...180, step: 1).accessibilityLabel("Orientation in room frame").accessibilityValue("\(Int(heading)) degrees")
                        TextField("Position note", text: $note, axis: .vertical).lineLimit(2...4)
                    }
                }
                if let failure { InlineFailure(message: failure) }
            }.navigationTitle("Place measurement").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) { Button("Place") { Task {
                    guard let room else { return }; working = true; defer { working = false }
                    let placement = RoomPlacement(roomID: room.roomID, revisionID: room.id, coordinateFrameID: room.coordinateFrameID, pose: pose, observedAt: .now, method: .manual, note: note)
                    do { try await onPlace(placement); dismiss() } catch { failure = error.localizedDescription }
                } }.disabled(room == nil || working || !pose.isValid).accessibilityIdentifier("placement.save") }
            }
            .onAppear { revisionID = original?.revisionID ?? library.index.roomRevisions.first?.id; note = original?.note ?? "" }
            .task(id: revisionID) {
                room = nil
                guard let revisionID else { return }
                do {
                    let value = try await library.archive.loadRoomRevision(revisionID)
                    guard !Task.isCancelled else { return }; room = value
                    let point = original?.revisionID == revisionID ? original?.pose.position : value.bounds.map { SpatialVector(($0.minimum.simd + $0.maximum.simd) / 2) }
                    x = Double(point?.x ?? 0); z = Double(point?.z ?? 0)
                    y = original?.revisionID == revisionID ? Double(point?.y ?? 1.2) : Double(value.bounds?.minimum.y ?? 0) + 1.2
                    heading = original?.revisionID == revisionID ? (original?.pose.heading ?? 0) * 180 / .pi : 0
                } catch { failure = error.localizedDescription }
            }.interactiveDismissDisabled(working)
        }
    }
    private func coordinate(_ title: String, value: Binding<Double>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number.precision(.fractionLength(0...2))).multilineTextAlignment(.trailing).frame(minWidth: 80).keyboardType(.numbersAndPunctuation) }
    }
}

struct FieldCaptureEvidence: View {
    let capture: FieldCapture
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if capture.demonstration { Label("Illustrative sample data", systemImage: "info.circle").foregroundStyle(ProTheme.band) }
            Text(capture.source).font(.system(.headline, design: .rounded))
            Text(capture.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(ProTheme.secondary)
            ForEach(capture.metrics) { metric in
                LabeledContent { Text("\(metric.formatted) \(metric.unit)").font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit().foregroundStyle(.primary) } label: {
                    Text(metric.title); Text(metric.qualifier).font(.caption).foregroundStyle(ProTheme.secondary)
                }
            }
            if let nfc = capture.nfc { NFCEvidenceView(read: nfc) }
            if !capture.probes.isEmpty { NetworkEvidenceView(probes: capture.probes) }
            if let depth = capture.depth { DepthEvidenceView(depth: depth) }
            if let surface = capture.surface { SurfaceEvidenceView(surface: surface) }
            if let forecasts = capture.forecasts { CellularForecastView(forecasts: forecasts, receivedAt: capture.date) }
            if let history = capture.cellularHistory { CellularHistoryView(history: history) }
            if capture.kind == .peer || capture.kind == .nearby { FieldSampleChart(capture: capture) }
            if capture.source == "Core Telephony" {
                ForEach(capture.samples) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.detail).font(.callout)
                        Text(event.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }
            }
            Text(capture.method).font(.callout).foregroundStyle(ProTheme.secondary)
            if !capture.diagnostics.isEmpty {
                DisclosureGroup("Capture diagnostics") {
                    ForEach(capture.diagnostics) { step in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.step).font(.callout.bold())
                            Text(step.outcome).font(.caption)
                            if let duration = step.duration { Text("\((duration * 1000).formatted(.number.precision(.fractionLength(0)))) ms").font(.caption).monospacedDigit() }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                    }
                }
            }
            ForEach(capture.metadata.keys.sorted(), id: \.self) { key in
                LabeledContent(Self.metadataTitle(key), value: capture.metadata[key] ?? "").font(.caption).textSelection(.enabled)
            }
        }
    }
    private static func metadataTitle(_ key: String) -> String {
        ["note": "Notes", "reportedTechnologyAtSave": "Technology when saved", "confidenceAtReticle": "Depth confidence at reticle",
         "method": "HTTP method", "pathContext": "System path context", "completion": "Completion", "routeRequirement": "Required route", "routeRule": "Route policy", "endpointQuery": "Endpoint query",
         "transport": "Connection", "mode": "Link mode", "directionStatus": "Direction", "status": "Status"][key] ?? key
    }
}

struct NFCEvidenceView: View {
    let read: NFCReadData
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Tag protocol", value: read.protocolName)
            if let id = read.identifier { LabeledContent("Reported identifier", value: id.hex).textSelection(.enabled) }
            LabeledContent("NDEF access", value: read.status)
            if let capacity = read.capacity {
                LabeledContent("Reported NDEF capacity", value: "\(capacity) bytes")
                if let bytes = read.messageBytes, capacity > 0 {
                    ProgressView(value: Double(min(bytes, capacity)), total: Double(capacity)).accessibilityLabel("NDEF message uses \(bytes) of \(capacity) bytes")
                    Text("\(bytes) encoded message bytes · \(max(0, capacity - bytes)) bytes remaining").font(.caption).foregroundStyle(ProTheme.secondary)
                }
            }
            ForEach(read.records) { record in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Record \(record.id + 1)").font(.headline)
                    if let decoded = record.decoded { Text(String(decoded.prefix(4000)) + (decoded.count > 4000 ? "\n… Full text is retained in the export." : "")).textSelection(.enabled) }
                    if let link = record.link, ["https", "http"].contains(link.scheme?.lowercased() ?? "") {
                        Link("Open \(link.host ?? "record link")", destination: link).frame(minHeight: 44)
                    }
                    DisclosureGroup("Raw record · \(record.byteCount) field bytes") {
                        Text("TNF \(record.format)\nType: \(record.type.hex)\nIdentifier: \(record.identifier.hex)\nPayload: \(record.payload.prefix(1024).hex)\(record.payload.count > 1024 ? "\n… Preview shows 1,024 bytes. Export retains the full payload." : "")")
                            .font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(12).background(ProTheme.signal.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct NetworkEvidenceView: View {
    let probes: [NetworkProbe]
    @State private var selected: UUID?
    private var probe: NetworkProbe? { probes.first { $0.id == selected } ?? probes.last }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Request consistency").font(.headline)
            let timeRange = 0...max(1, probes.map(\.elapsed).max() ?? 1)
            if probes.contains(where: \.succeeded) {
                Chart(probes.filter(\.succeeded)) { probe in
                    PointMark(x: .value("Elapsed seconds", probe.elapsed), y: .value("Request time ms", probe.durationMS)).foregroundStyle(ProTheme.signal)
                }.frame(height: 160).chartYAxisLabel("ms").chartXAxisLabel("Elapsed seconds").chartXScale(domain: timeRange)
            } else { Text("No successful request times").font(.callout) }
            if probes.contains(where: { !$0.succeeded }) {
                Text("Failed requests").font(.caption.bold())
                Chart(probes.filter { !$0.succeeded }) { probe in
                    PointMark(x: .value("Elapsed seconds", probe.elapsed), y: .value("Failed request", 0)).symbol(.cross).foregroundStyle(.primary)
                }.frame(height: 24).chartXScale(domain: timeRange).chartYAxis(.hidden).chartXAxis(.hidden)
                    .accessibilityLabel("Failure timeline, separate from response times")
            }
            Text("Failures are shown separately and excluded from response times. Missing observations are left blank.").font(.caption).foregroundStyle(ProTheme.secondary)
            Picker("Inspect request", selection: $selected) {
                Text("Latest request").tag(Optional<UUID>.none)
                ForEach(Array(probes.enumerated()), id: \.element.id) { index, probe in
                    Text("\(index + 1) · \(probe.succeeded ? "\(Int(probe.durationMS)) ms" : "Failed")").tag(Optional(probe.id))
                }
            }
            if let probe {
                if let error = probe.error { InlineFailure(message: error) }
                ForEach(probe.transactions) { transaction in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.host).font(.callout.bold())
                        Text("\(transaction.protocolName ?? "Protocol unavailable") · \(transaction.cellular ? "Cellular" : "Other route")\(transaction.reused ? " · Reused connection" : "")\(transaction.cached ? " · Cached response" : "")").font(.caption).foregroundStyle(ProTheme.secondary)
                        Chart(transaction.phases) { phase in
                            BarMark(xStart: .value("Start ms", phase.start * 1000), xEnd: .value("End ms", phase.end * 1000), y: .value("Phase", phase.name))
                                .foregroundStyle(phase.id == "tls" ? ProTheme.band : ProTheme.signal)
                        }.frame(height: CGFloat(max(1, transaction.phases.count)) * 28 + 24).chartXAxisLabel("Milliseconds from request start")
                        Text("TLS overlaps connection setup. Missing phases are unavailable or reused; phase bars are not additive.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }
            }
        }
    }
}

struct DepthEvidenceView: View {
    let depth: DepthEvidence
    @State private var confidence = false
    @State private var selectedPixel: Int?
    private var pixel: Int { min(depth.meters.count - 1, max(0, selectedPixel ?? (depth.height / 2 * depth.width + depth.width / 2))) }
    private var pixelDescription: String {
        guard depth.isValid, depth.meters.indices.contains(pixel) else { return "Depth unavailable" }
        let reading = depth.meters[pixel].map { "\($0.formatted(.number.precision(.fractionLength(2)))) m" } ?? "No valid depth"
        let quality = depth.confidence.isEmpty ? "confidence unavailable" : ["low", "medium", "high"][Int(depth.confidence[pixel])] + " confidence"
        return "Pixel \(pixel % depth.width), \(pixel / depth.width): \(reading) · \(quality)"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Depth display", selection: $confidence) { Text("Depth").tag(false); Text("Confidence").tag(true) }.pickerStyle(.segmented)
            GeometryReader { geometry in
                Canvas { context, size in
                    guard depth.isValid else { return }
                    for y in 0..<depth.height { for x in 0..<depth.width {
                        let i = y * depth.width + x
                        let color: Color
                        if depth.meters[i] == nil { color = .clear }
                        else if confidence { color = depth.confidence.isEmpty ? .gray : [Color.gray.opacity(0.35), Color.orange, ProTheme.band][Int(depth.confidence[i])] }
                        else {
                            let t = Double(max(0, min(1, ((depth.meters[i] ?? depth.minimum) - depth.minimum) / (depth.maximum - depth.minimum))))
                            color = Self.cividis(t)
                        }
                        let rect = CGRect(x: Double(x) / Double(depth.width) * size.width, y: Double(y) / Double(depth.height) * size.height,
                                          width: size.width / Double(depth.width) + 0.5, height: size.height / Double(depth.height) + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    } }
                    let x = Double(pixel % depth.width) / Double(depth.width) * size.width
                    let y = Double(pixel / depth.width) / Double(depth.height) * size.height
                    let ring = Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14))
                    context.stroke(ring, with: .color(.black), lineWidth: 4)
                    context.stroke(ring, with: .color(.white), lineWidth: 2)
                }.contentShape(Rectangle()).gesture(SpatialTapGesture().onEnded { event in
                    let x = min(depth.width - 1, max(0, Int(event.location.x / max(1, geometry.size.width) * Double(depth.width))))
                    let y = min(depth.height - 1, max(0, Int(event.location.y / max(1, geometry.size.height) * Double(depth.height))))
                    selectedPixel = y * depth.width + x
                })
            }.aspectRatio(CGFloat(max(1, depth.width)) / CGFloat(max(1, depth.height)), contentMode: .fit)
                .background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityElement().accessibilityLabel("Depth grid").accessibilityValue(pixelDescription)
                .accessibilityAdjustableAction { direction in
                    switch direction { case .increment: selectedPixel = min(depth.meters.count - 1, pixel + 1); case .decrement: selectedPixel = max(0, pixel - 1); @unknown default: break }
                }
            Text(pixelDescription).font(.callout).monospacedDigit()
            Text(confidence ? "Gray: low · Orange: medium · Green: high. Blank pixels have no valid depth." : "Blue: \(depth.minimum.formatted()) m · Yellow: \(depth.maximum.formatted()) m. Tap to inspect; blank pixels have no valid depth.")
                .font(.caption).foregroundStyle(ProTheme.secondary)
            let clipped = depth.meters.compactMap { $0 }.filter { $0 < depth.minimum || $0 > depth.maximum }.count
            if clipped > 0 { Text("\(clipped) samples fall outside the color scale and use an endpoint color. Their original depths remain available.").font(.caption).foregroundStyle(ProTheme.secondary) }
        }.accessibilityElement(children: .contain)
    }
    private static func cividis(_ value: Double) -> Color {
        // Nine evenly spaced cividis samples, Matplotlib 3.10.8. Values increase perceptually from dark to light.
        let stops: [SIMD3<Double>] = [.init(0, 0.135112, 0.304751), .init(0.103401, 0.220406, 0.435790), .init(0.263738, 0.307831, 0.422789),
            .init(0.380830, 0.395164, 0.435653), .init(0.488697, 0.485318, 0.471008), .init(0.609105, 0.579816, 0.463638),
            .init(0.736488, 0.680629, 0.424028), .init(0.870717, 0.789572, 0.343333), .init(0.995737, 0.909344, 0.217772)]
        let position = min(1, max(0, value)) * Double(stops.count - 1), i = min(stops.count - 2, Int(position))
        let color = stops[i] + (stops[i + 1] - stops[i]) * (position - Double(i))
        return Color(red: color.x, green: color.y, blue: color.z)
    }
}

struct FieldCaptureComparison: View {
    let current: FieldCapture
    let earlier: FieldCapture
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared with \(earlier.title)").font(.headline)
            Text(earlier.date.formatted(date: .abbreviated, time: .standard)).font(.caption)
            if current.source != earlier.source { Text("Sources differ. Compare only where the methods and conditions are compatible.").font(.callout).foregroundStyle(ProTheme.secondary) }
            ForEach(current.metrics) { metric in
                if let previous = earlier.metrics.first(where: { $0.id == metric.id && $0.unit == metric.unit }) {
                    LabeledContent(metric.title, value: "\(previous.formatted) → \(metric.formatted) \(metric.unit)")
                }
            }
            if let first = earlier.nfc, let second = current.nfc {
                LabeledContent("Identifier", value: first.identifier == nil || second.identifier == nil ? "Unavailable for one or both reads" : first.identifier == second.identifier ? "Same reported value" : "Different reported values")
                LabeledContent("NDEF contents", value: first.records == second.records ? "Unchanged" : "Changed")
                LabeledContent("NDEF access", value: "\(first.status) → \(second.status)")
                ForEach(0..<max(first.records.count, second.records.count), id: \.self) { index in
                    let before = first.records.indices.contains(index) ? first.records[index] : nil
                    let after = second.records.indices.contains(index) ? second.records[index] : nil
                    if before != after {
                        DisclosureGroup("Record \(index + 1) · \(before == nil ? "Added" : after == nil ? "Removed" : "Changed")") {
                            Text("Field bytes: \(before?.byteCount ?? 0) → \(after?.byteCount ?? 0)").font(.caption)
                            if let before { Text("Earlier payload: \(before.payload.prefix(256).hex)").font(.caption.monospaced()).textSelection(.enabled) }
                            if let after { Text("Current payload: \(after.payload.prefix(256).hex)").font(.caption.monospaced()).textSelection(.enabled) }
                            Text("Byte previews show at most 256 payload bytes. Open each capture for its full record fields and export.").font(.caption).foregroundStyle(ProTheme.secondary)
                        }
                    }
                }
            }
        }
    }
}

extension Data {
    nonisolated var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
