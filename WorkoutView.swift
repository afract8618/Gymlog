import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.createdAt) private var people: [Person]
    @Query private var sessions: [Session]
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @AppStorage("activePersonID") private var activePersonID = ""
    @AppStorage("selectedDayID") private var selectedDayID = "d1"
    @FocusState private var focusedField: String?
    @State private var confirmDiscard = false

    private var person: Person? {
        people.first { $0.id.uuidString == activePersonID } ?? people.first
    }

    private var activeSession: Session? {
        guard let p = person else { return nil }
        return sessions.first { $0.personID == p.id && $0.endedAt == nil }
    }

    private var day: WorkoutDay { Program.day(activeSession?.dayID ?? selectedDayID) }

    var body: some View {
        NavigationStack {
            List {
                if people.count > 1 {
                    Section { PersonPicker() }
                }

                Section { dayPicker }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                Section { statusCard }

                Section(day.title) {
                    ForEach(day.exercises) { ex in
                        ExerciseRow(
                            exercise: ex,
                            isDone: activeSession?.completedIDs.contains(ex.id) ?? false,
                            current: latestEntry(for: ex)?.weight,
                            previous: previousEntry(for: ex),
                            tint: day.color,
                            focus: $focusedField,
                            onToggle: { toggle(ex) },
                            onSetWeight: { setWeight($0, for: ex) }
                        )
                    }
                }

                if let s = activeSession {
                    Section {
                        Button {
                            s.completedIDs = day.exercises.map(\.id)
                        } label: {
                            Label("Mark all exercises done", systemImage: "checkmark.circle")
                        }
                        Button {
                            focusedField = nil
                            s.endedAt = .now
                        } label: {
                            Label("Finish workout", systemImage: "flag.checkered")
                                .bold()
                        }
                        .disabled(s.completedIDs.isEmpty)
                        Button("Discard this workout", role: .destructive) {
                            confirmDiscard = true
                        }
                    } footer: {
                        Text("Finishing saves today to your calendar: all done counts as a full day, anything less as partial.")
                    }
                }
            }
            .navigationTitle(person.map { "\($0.name)'s workout" } ?? "Workout")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    if let s = activeSession { context.delete(s) }
                }
            } message: {
                Text("The timer and checkmarks are removed. Weights you logged stay saved.")
            }
        }
    }

    // MARK: Pieces

    private var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(Array(Program.days.enumerated()), id: \.element.id) { index, d in
                let selected = d.id == day.id
                Button {
                    selectedDayID = d.id
                } label: {
                    VStack(spacing: 2) {
                        Text(d.short).font(.headline)
                        Text("Day \(index + 1)").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected ? d.color : Color(.secondarySystemGroupedBackground),
                                in: Capsule())
                    .foregroundStyle(selected ? Color.white : Color.primary)
                }
                .buttonStyle(.borderless)
                .disabled(activeSession != nil && !selected)
                .opacity(activeSession != nil && !selected ? 0.4 : 1)
            }
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if let s = activeSession {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TIME").font(.caption).foregroundStyle(.secondary)
                        Text(s.startedAt, style: .timer)
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    }
                    Spacer()
                    Text("\(s.completedIDs.count) of \(day.exercises.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(s.completedIDs.count), total: Double(day.exercises.count))
                    .tint(day.color)
            }
            .padding(.vertical, 4)
        } else {
            Button {
                if let p = person { _ = startSession(for: p) }
            } label: {
                Label("Start workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(day.color)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: Actions

    private func startSession(for p: Person) -> Session {
        let s = Session(personID: p.id, dayID: day.id, totalCount: day.exercises.count)
        context.insert(s)
        return s
    }

    private func toggle(_ ex: Exercise) {
        guard let p = person else { return }
        let s = activeSession ?? startSession(for: p)
        var ids = s.completedIDs
        if let i = ids.firstIndex(of: ex.id) { ids.remove(at: i) } else { ids.append(ex.id) }
        s.completedIDs = ids
    }

    private func history(for ex: Exercise) -> [WeightEntry] {
        guard let p = person else { return [] }
        return entries.filter { $0.personID == p.id && $0.exerciseID == ex.id }
    }

    private func latestEntry(for ex: Exercise) -> WeightEntry? {
        history(for: ex).last
    }

    private func previousEntry(for ex: Exercise) -> WeightEntry? {
        history(for: ex).last { !Calendar.current.isDateInToday($0.date) }
    }

    private func setWeight(_ value: Double?, for ex: Exercise) {
        guard let p = person else { return }
        let todays = history(for: ex).filter { Calendar.current.isDateInToday($0.date) }
        if let v = value {
            if let e = todays.first {
                e.weight = v
            } else {
                context.insert(WeightEntry(personID: p.id, exerciseID: ex.id, weight: v))
            }
        } else {
            todays.forEach { context.delete($0) }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let isDone: Bool
    let current: Double?
    let previous: WeightEntry?
    let tint: Color
    var focus: FocusState<String?>.Binding
    let onToggle: () -> Void
    let onSetWeight: (Double?) -> Void

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(isDone ? tint : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isDone ? "Mark \(exercise.name) not done" : "Mark \(exercise.name) done")

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.headline).strikethrough(isDone)
                    Text(exercise.scheme).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                stepButton(systemImage: "minus", delta: -5)
                TextField(exercise.weighted ? "lb" : "+lb", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit().bold())
                    .frame(width: 80)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    .focused(focus, equals: exercise.id)
                stepButton(systemImage: "plus", delta: 5)
                Text(exercise.weighted ? "lb" : "lb added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 44)

            Text(lastText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 44)
        }
        .padding(.vertical, 4)
        .onAppear { text = formatWeight(current) }
        .onChange(of: current) { _, new in
            if focus.wrappedValue != exercise.id { text = formatWeight(new) }
        }
        .onChange(of: focus.wrappedValue) { old, new in
            if old == exercise.id && new != exercise.id { commit() }
        }
    }

    private var lastText: String {
        guard let prev = previous else {
            return current == nil ? "No weight logged yet" : "First time logging this"
        }
        var s = "Last time: \(formatWeight(prev.weight)) lb · \(prev.date.formatted(.dateTime.month(.abbreviated).day()))"
        if let c = current, c > prev.weight { s += "  ▲ +\(formatWeight(c - prev.weight))" }
        return s
    }

    private func stepButton(systemImage: String, delta: Double) -> some View {
        Button {
            let base = Double(text) ?? current ?? 0
            let v = max(0, base + delta)
            text = formatWeight(v)
            onSetWeight(v)
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { onSetWeight(nil); return }
        if let v = Double(trimmed) { onSetWeight(max(0, v)) } else { text = formatWeight(current) }
    }
}
