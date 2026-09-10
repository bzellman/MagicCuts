import SwiftUI
import PDFKit

struct FieldReportsView: View {
    @Bindable var library: ProLibrary
    @State private var creating = false
    @State private var deleting: FieldReport?
    var body: some View {
        List {
            Section {
                Text("Bring a measurement story together.").font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Group sessions by a project or place, add your protocol and observations, then share one report.").font(.callout).foregroundStyle(ProTheme.secondary)
            }.listRowBackground(Color.clear)
            Section {
                ForEach(library.index.reports) { report in
                    NavigationLink { FieldReportDetailView(id: report.id, library: library) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(report.title).font(.system(.headline, design: .rounded))
                            if !report.location.isEmpty { Text(report.location).font(.callout).foregroundStyle(ProTheme.secondary) }
                            Text("\(report.sessionIDs.count) sessions · \(report.steps.filter(\.complete).count) of \(report.steps.count) protocol steps checked")
                                .font(.caption).foregroundStyle(ProTheme.secondary)
                        }.padding(.vertical, 8)
                    }.swipeActions { Button("Delete", role: .destructive) { deleting = report } }
                }
                Button { creating = true } label: { Label("New field report", systemImage: "plus").frame(minHeight: 44) }.accessibilityIdentifier("report.new")
            }
            if let error = library.error { InlineFailure(message: error) }
        }
        .navigationTitle("Field reports")
        .sheet(isPresented: $creating) { FieldReportEditorView(library: library) }
        .confirmationDialog("Delete this field report?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete report", role: .destructive) {
                guard let report = deleting else { return }; deleting = nil
                Task { do { _ = try await library.archive.deleteReport(report.id); await library.reload() } catch { library.error = error.localizedDescription } }
            }
        } message: { Text("Its measurement sessions remain saved in your library.") }
    }
}

struct FieldReportEditorView: View {
    @Bindable var library: ProLibrary
    var existing: FieldReport?
    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var steps: [FieldProtocolStep] = []
    @State private var stepName = ""
    @State private var selected = Set<UUID>()
    @State private var saving = false
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    private var unavailableSelections: [UUID] {
        selected.filter { id in !library.index.sessions.contains { $0.id == id } }.sorted { $0.uuidString < $1.uuidString }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Project or visit") {
                    TextField("Report title", text: $title).accessibilityIdentifier("report.title")
                    TextField("Place or setup (optional)", text: $location)
                }
                Section {
                    ForEach($steps) { $step in Toggle(step.title, isOn: $step.complete) }
                        .onDelete { steps.remove(atOffsets: $0) }
                        .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("Add a protocol step", text: $stepName)
                        Button { steps.append(FieldProtocolStep(title: stepName.trimmingCharacters(in: .whitespacesAndNewlines))); stepName = "" } label: { Image(systemName: "plus.circle.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel("Add protocol step").disabled(stepName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: { Text("Your test protocol") } footer: { Text("Checked steps are your own confirmations. MagicCuts does not mark a physical procedure complete automatically.") }
                Section("Measurement sessions") {
                    if library.index.sessions.isEmpty { Text("Record a session in Instruments, then attach it here.").foregroundStyle(ProTheme.secondary) }
                    ForEach(library.index.sessions) { session in
                        Toggle(isOn: Binding(get: { selected.contains(session.id) }, set: { if $0 { selected.insert(session.id) } else { selected.remove(session.id) } })) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.title).font(.system(.headline, design: .rounded))
                                Text("\(session.kind.title) · \(session.sampleCount) readings").font(.caption).foregroundStyle(ProTheme.secondary)
                            }.padding(.vertical, 5)
                        }
                    }
                    ForEach(Array(unavailableSelections.enumerated()), id: \.element) { offset, id in
                        Toggle(isOn: Binding(get: { selected.contains(id) }, set: { if !$0 { selected.remove(id) } })) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Unavailable attachment \(offset + 1)").font(.headline)
                                Text("This session may still be syncing or may have been deleted. Turn this off to remove it from the report.")
                                    .font(.caption).foregroundStyle(ProTheme.secondary)
                            }
                        }
                    }
                }
                Section("Observations") { TextField("What changed? What did you notice?", text: $notes, axis: .vertical).lineLimit(4 ... 12) }
                if let failure { InlineFailure(message: failure) }
            }
            .navigationTitle(existing == nil ? "New field report" : "Edit field report").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("report.save") }
            }
            .onAppear {
                if let existing { title = existing.title; location = existing.location; notes = existing.notes; steps = existing.steps; selected = Set(existing.sessionIDs) }
            }
            .interactiveDismissDisabled(saving)
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        var report = existing ?? FieldReport(title: title)
        report.title = title.trimmingCharacters(in: .whitespacesAndNewlines); report.location = location; report.notes = notes; report.steps = steps
        report.sessionIDs = library.index.sessions.filter { selected.contains($0.id) }.sorted { $0.startedAt < $1.startedAt }.map(\.id) + unavailableSelections
        report.updatedAt = .now
        do { try await library.save(report); dismiss() } catch { failure = error.localizedDescription }
    }
}

struct FieldReportDetailView: View {
    let id: UUID
    @Bindable var library: ProLibrary
    @State private var editing = false
    @State private var exporting = false
    @State private var files: [ReportFile] = []
    @State private var failure: String?
    private var report: FieldReport? { library.index.reports.first { $0.id == id } }
    private var exportRevision: [LibraryVersion?] {
        [library.index.versions[LibraryRecord.key(.report, id)]] + (report?.sessionIDs.map { library.index.versions[LibraryRecord.key(.session, $0)] } ?? [])
    }
    var body: some View {
        List {
            if let report {
                Section {
                    if !report.location.isEmpty { Label(report.location, systemImage: "mappin").font(.system(.headline, design: .rounded)) }
                    Text("Updated \(report.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(ProTheme.secondary)
                }
                if !report.steps.isEmpty {
                    Section("Your protocol") {
                        ForEach(report.steps) { step in
                            Label(step.title, systemImage: step.complete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.complete ? ProTheme.band : .primary).accessibilityLabel("\(step.title), \(step.complete ? "checked by you" : "not checked")")
                        }
                    }
                }
                Section("Measurements") {
                    ForEach(report.sessionIDs, id: \.self) { sessionID in
                        if let session = library.index.sessions.first(where: { $0.id == sessionID }) {
                            NavigationLink { SessionDetailView(id: sessionID, library: library) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.title).font(.system(.headline, design: .rounded))
                                    Text("\(session.kind.title) · \(session.sampleCount) readings").font(.callout).foregroundStyle(ProTheme.secondary)
                                }
                            }
                        } else { Label("An attached session is unavailable", systemImage: "exclamationmark.circle") }
                    }
                    if report.sessionIDs.isEmpty { Text("No measurement sessions attached yet.").foregroundStyle(ProTheme.secondary) }
                }
                if !report.notes.isEmpty { Section("Observations") { Text(report.notes) } }
                Section {
                    Button {
                        exporting = true; failure = nil; files = []
                        let revision = exportRevision
                        Task {
                            defer { exporting = false }
                            do {
                                var sessions: [RecordedSession] = []
                                for sessionID in report.sessionIDs { sessions.append(try await library.archive.loadSession(sessionID)) }
                                guard exportRevision == revision else {
                                    failure = "This report changed while it was being prepared. Prepare it again to include the latest measurements."
                                    return
                                }
                                files = try FieldReportExport.export(report, sessions: sessions)
                            } catch { failure = "The report couldn't be prepared. \(error.localizedDescription)" }
                        }
                    } label: { HStack { if exporting { ProgressView() }; Label("Prepare report", systemImage: "doc.richtext").frame(minHeight: 44) } }.disabled(exporting)
                    ForEach(files) { file in ShareLink(item: file.url) { Label(file.title, systemImage: file.symbol).frame(minHeight: 44) } }
                } footer: { Text("The PDF includes your protocol and observations, followed by each session's chart, method and marks. JSON also includes every numerical reading.") }
                if let failure { InlineFailure(message: failure) }
            } else { ContentUnavailableView("Report unavailable", systemImage: "doc.questionmark", description: Text("It may have been deleted.")) }
        }
        .navigationTitle(report?.title ?? "Field report").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true }.disabled(report == nil || exporting) }
        .sheet(isPresented: $editing, onDismiss: { files = [] }) { if let report { FieldReportEditorView(library: library, existing: report) } }
        .onChange(of: exportRevision) { _, _ in files = [] }
    }
}

@MainActor
enum FieldReportExport {
    private struct Payload: Encodable {
        let report: FieldReport
        let sessions: [RecordedSession]
    }
    static func export(_ report: FieldReport, sessions: [RecordedSession]) throws -> [ReportFile] {
        guard Set(report.sessionIDs) == Set(sessions.map(\.id)) else { throw InstrumentError.storage("A measurement session is missing. Edit the report's attachments and try again.") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-Exports", isDirectory: true).appendingPathComponent(report.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let cover = renderer.pdfData { context in
            var y: CGFloat = 52
            var page = 0
            func newPage() {
                context.beginPage(); y = 52; page += 1
                "MagicCuts Pro · Field report · \(page)".draw(at: CGPoint(x: 46, y: 755), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
            }
            func block(_ text: String, size: CGFloat = 12, weight: UIFont.Weight = .regular) {
                let characters = Array(text)
                for start in stride(from: 0, to: characters.count, by: 500) {
                    let part = String(characters[start ..< min(start + 500, characters.count)])
                    let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: UIColor.black]
                    let rect = (part as NSString).boundingRect(with: CGSize(width: 520, height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                    if y + rect.height > 710 { newPage() }
                    (part as NSString).draw(in: CGRect(x: 46, y: y, width: 520, height: ceil(rect.height) + 2), withAttributes: attributes)
                    y += ceil(rect.height) + 14
                }
            }
            newPage()
            block("MAGICCUTS PRO · FIELD REPORT", size: 10, weight: .bold)
            block(report.title, size: 28, weight: .bold)
            if !report.location.isEmpty { block(report.location, size: 16, weight: .semibold) }
            block("Updated \(report.updatedAt.formatted(date: .complete, time: .standard))", size: 10)
            block("\(sessions.count) measurement \(sessions.count == 1 ? "session" : "sessions") attached. All observations and protocol confirmations below were entered by the person using the app.", size: 11)
            if !report.steps.isEmpty {
                block("Test protocol", size: 16, weight: .bold)
                for (index, step) in report.steps.enumerated() { block("\(index + 1). [\(step.complete ? "Checked by you" : "Not checked")] \(step.title)") }
            }
            if !report.notes.isEmpty { block("Observations", size: 16, weight: .bold); block(report.notes) }
            block("Attached measurements", size: 16, weight: .bold)
            for session in sessions { block("\(session.title) · \(session.kind.title) · \(session.points.count) readings", size: 11) }
            if sessions.isEmpty { block("No measurements are attached to this report.") }
        }
        guard let combined = PDFDocument(data: cover) else { throw InstrumentError.storage("The report cover couldn't be created.") }
        var sanitized: [RecordedSession] = []
        for session in sessions {
            let exported = try SessionReport.export(session)
            guard let pdf = exported.first(where: { $0.url.pathExtension == "pdf" }), let document = PDFDocument(url: pdf.url),
                  let json = exported.first(where: { $0.url.pathExtension == "json" }) else { throw InstrumentError.storage("An attached session couldn't be exported.") }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            sanitized.append(try decoder.decode(RecordedSession.self, from: Data(contentsOf: json.url)))
            for index in 0 ..< document.pageCount { if let page = document.page(at: index) { combined.insert(page, at: combined.pageCount) } }
        }
        let pdf = directory.appendingPathComponent("MagicCuts-field-report.pdf")
        guard let data = combined.dataRepresentation() else { throw InstrumentError.storage("The complete report couldn't be rendered.") }
        try data.write(to: pdf, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let json = directory.appendingPathComponent("MagicCuts-field-report.json")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Payload(report: report, sessions: sanitized)).write(to: json, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return [ReportFile(title: "Share PDF field report", symbol: "doc.richtext", url: pdf), ReportFile(title: "Share complete JSON", symbol: "curlybraces", url: json)]
    }
}
