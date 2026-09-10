import SwiftUI
import UniformTypeIdentifiers

struct SessionsView: View {
    @Bindable var library: ProLibrary
    var activeRecordingID: UUID?
    @State private var recovering: RecordedSession?
    @State private var search = ""
    @State private var deleting: SessionIndexEntry?
    private var sessions: [SessionIndexEntry] {
        library.index.sessions.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.kind.title.localizedCaseInsensitiveContains(search) || $0.sourceName.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            let drafts = library.recovered.filter { $0.id != activeRecordingID }
            if !drafts.isEmpty {
                Section("Unfinished recordings") {
                    ForEach(drafts) { draft in
                        Button { recovering = draft } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(draft.kind.title, systemImage: "arrow.counterclockwise").font(.system(.headline, design: .rounded))
                                Text("\(draft.points.count) readings recovered · \(draft.endedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(ProTheme.secondary)
                            }.padding(.vertical, 8)
                        }
                    }
                }
            }
            Section {
                NavigationLink { FieldReportsView(library: library) } label: {
                    HStack {
                        Label("Field reports", systemImage: "doc.text.magnifyingglass").font(.system(.headline, design: .rounded))
                        Spacer(); Text("\(library.index.reports.count)").foregroundStyle(ProTheme.secondary)
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("reports.open")
            }
            if let error = library.error { InlineFailure(message: error) }
            if library.loading { ProgressView("Opening sessions…") }
            ForEach(sessions) { session in
                NavigationLink {
                    SessionDetailView(id: session.id, library: library)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(session.title).font(.system(.headline, design: .rounded))
                            Spacer(minLength: 10)
                            Image(systemName: session.kind.symbol).foregroundStyle(ProTheme.signal)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            MeasurementValue(value: session.median, kind: session.kind, compact: true)
                            Spacer(minLength: 6)
                            Text("\(session.sampleCount) readings").font(.caption).foregroundStyle(ProTheme.secondary)
                        }
                        Text("\(session.sourceName) · \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(ProTheme.secondary)
                    }.padding(.vertical, 12)
                }
                .swipeActions { Button("Delete", role: .destructive) { deleting = session } }
            }
        }
        .overlay {
            if sessions.isEmpty && !library.loading && library.error == nil {
                ContentUnavailableView(search.isEmpty ? "Keep the useful moments" : "No matching sessions", systemImage: "waveform.path", description: Text(search.isEmpty ? "Record an instrument session, mark what changed, then return here to compare and export it." : "Try another name, source or instrument."))
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle("Sessions")
        .searchable(text: $search, prompt: "Name, source or instrument")
        .refreshable { await library.reload() }
        .sheet(item: $recovering) { draft in RecoveredSessionView(session: draft, library: library) }
        .confirmationDialog("Delete this session?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete session", role: .destructive) {
                guard let deleting else { return }
                self.deleting = nil
                Task {
                    do { _ = try await library.archive.deleteSession(deleting.id); await library.reload() }
                    catch { library.error = error.localizedDescription }
                }
            }
        } message: { Text("This removes the saved recording from this device. Exported files are unaffected.") }
    }
}

struct RecoveredSessionView: View {
    let session: RecordedSession
    @Bindable var library: ProLibrary
    @State private var title = ""
    @State private var failure: String?
    @State private var working = false
    @State private var discard = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Session name") { TextField("Name the recovered recording", text: $title) }
                Section {
                    LabeledContent("Recovered readings", value: "\(session.points.count)")
                    LabeledContent("Recovered through", value: session.endedAt.formatted(date: .abbreviated, time: .standard))
                    Text("MagicCuts keeps recovery copies during recording and when a session pauses. Readings after this copy are unavailable.").font(.callout).foregroundStyle(ProTheme.secondary)
                }
                Section { Button("Discard recovery copy", role: .destructive) { discard = true }.disabled(working) }
                if let failure { InlineFailure(message: failure) }
            }
            .navigationTitle("Recover session").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(working || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .onAppear { title = session.title }
            .confirmationDialog("Discard this recovered recording?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard recording", role: .destructive) {
                    Task {
                        do { try await library.archive.discardDraft(session.id); await library.reload(); dismiss() }
                        catch { failure = error.localizedDescription }
                    }
                }
            }
            .interactiveDismissDisabled(working)
        }
    }
    private func save() async {
        working = true; defer { working = false }
        var recovered = session
        recovered.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        recovered.termination = "Recovered through the last saved copy. Later readings are unavailable."
        do {
            try await library.save(recovered)
            try await library.archive.discardDraft(session.id)
            await library.reload(); dismiss()
        } catch { failure = error.localizedDescription }
    }
}

struct SessionDetailView: View {
    let id: UUID
    @Bindable var library: ProLibrary
    @State private var session: RecordedSession?
    @State private var failure: String?
    @State private var selectedElapsed: Double?
    @State private var files: [ReportFile] = []
    @State private var exporting = false
    @State private var showExport = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let session {
                    Text(session.source.reportName).font(.callout).foregroundStyle(ProTheme.secondary)
                    if let summary = session.summary {
                        MeasurementValue(value: selectedElapsed.flatMap { selected in session.points.min { abs($0.elapsed - selected) < abs($1.elapsed - selected) }?.value } ?? summary.median, kind: session.kind)
                        Text(selectedElapsed == nil ? "Session median" : "Selected reading").font(.callout).foregroundStyle(ProTheme.secondary)
                        InstrumentHistoryChart(points: session.points, kind: session.kind, range: session.kind.displayRange(values: session.points.map(\.value) + (session.reference?.points.map(\.value) ?? [])), baseline: session.reference?.points ?? [], threshold: session.source.threshold, events: session.events, selectedElapsed: $selectedElapsed, height: 250)
                        if selectedElapsed != nil { Button("Show session summary") { selectedElapsed = nil }.frame(minHeight: 44) }
                        if let reference = session.reference {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Compared with \(reference.name)").font(.system(.headline, design: .rounded))
                                MeasurementValue(value: MeasurementMath.delta(summary.median, baseline: reference.summary.median, kind: session.kind), kind: session.kind, signed: true, compact: true)
                                Text("Change in median · dashed line is your saved reference.").font(.caption).foregroundStyle(ProTheme.secondary)
                            }
                        }
                        VStack(spacing: 12) {
                            LabeledContent("Readings", value: "\(summary.count)")
                            LabeledContent("Duration", value: "\(session.duration.formatted(.number.precision(.fractionLength(1)))) seconds")
                            LabeledContent("Middle 50%", value: "\(session.kind.formatted(summary.q25)) to \(session.kind.formatted(summary.q75)) \(session.kind.unit)")
                            LabeledContent("Range", value: "\(session.kind.formatted(summary.minimum)) to \(session.kind.formatted(summary.maximum)) \(session.kind.unit)")
                        }.font(.callout)
                    }
                    if !session.events.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Session marks").font(.system(.headline, design: .rounded))
                            ForEach(session.events) { event in
                                HStack(alignment: .top, spacing: 16) {
                                    Text("\(event.elapsed.formatted(.number.precision(.fractionLength(1))))s").monospacedDigit().foregroundStyle(ProTheme.secondary)
                                    Text(event.text)
                                }.font(.callout)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Measurement details").font(.system(.headline, design: .rounded))
                        Text(session.method)
                        Text("Started \(session.startedAt.formatted(date: .abbreviated, time: .standard)). \(session.termination).")
                        Text("The plot preserves interruptions. Readings were observed while the app was in the foreground.")
                    }.font(.callout).foregroundStyle(ProTheme.secondary)
                    Button {
                        exporting = true
                        Task {
                            do { files = try SessionReport.export(session); showExport = true }
                            catch { failure = error.localizedDescription }
                            exporting = false
                        }
                    } label: {
                        HStack { if exporting { ProgressView().tint(.white) }; Label("Export session", systemImage: "square.and.arrow.up") }
                    }.buttonStyle(ControlStyle()).disabled(exporting).accessibilityIdentifier("session.export")
                } else if failure == nil { ProgressView("Opening session…").frame(maxWidth: .infinity) }
                if let failure {
                    InlineFailure(message: failure)
                    Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                }
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(MC.canvas)
        .navigationTitle(session?.title ?? "Session").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showExport) {
            NavigationStack {
                List {
                    Section {
                        ForEach(files) { file in ShareLink(item: file.url) { Label(file.title, systemImage: file.symbol).frame(minHeight: 44) } }
                    } footer: {
                        Text("PDF includes the summary, chart and every session mark. CSV contains every reading. JSON also includes the baseline and measurement details. Endpoint query strings are removed from exports.")
                    }
                }
                .navigationTitle("Export session").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showExport = false } } }
            }.presentationDetents([.medium, .large])
        }
    }
    private func load() async {
        do { session = try await library.archive.loadSession(id); failure = nil }
        catch { failure = "This recording couldn't be opened. \(error.localizedDescription)" }
    }
}
