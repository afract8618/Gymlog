import SwiftUI
import SwiftData

@main
struct GymLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Person.self, Session.self, WeightEntry.self, BodyWeight.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Person.createdAt) private var people: [Person]
    @Query private var sessions: [Session]
    @AppStorage("activePersonID") private var activePersonID = ""
    @AppStorage("trainingDays") private var trainingDaysRaw = "2,3,5,6"
    @AppStorage("remindersOn") private var remindersOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 17 * 60

    var body: some View {
        TabView {
            WorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell") }
            LiftsView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("People", systemImage: "person.2") }
        }
        .task {
            if people.isEmpty {
                let me = Person(name: "Me", goalWeight: 160)
                context.insert(me)
                activePersonID = me.id.uuidString
            }
            sync()
        }
        .onChange(of: people.map(\.id)) { _, ids in
            if !ids.contains(where: { $0.uuidString == activePersonID }), let first = ids.first {
                activePersonID = first.uuidString
            }
        }
        .onChange(of: sessionSignature) { _, _ in sync() }
        .onChange(of: activePersonID) { _, _ in sync() }
        .onChange(of: trainingDaysRaw) { _, _ in sync() }
        .onChange(of: remindersOn) { _, _ in sync() }
        .onChange(of: reminderMinutes) { _, _ in sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync() }
        }
    }

    /// Changes whenever a workout starts, finishes, or gets ticked.
    private var sessionSignature: String {
        sessions.map { "\($0.id)-\($0.endedAt?.timeIntervalSince1970 ?? 0)-\($0.completedIDs.count)" }
            .joined(separator: "|")
    }

    private func sync() {
        let days = Set(trainingDaysRaw.split(separator: ",").compactMap { Int($0) })
        SnapshotWriter.update(people: people, sessions: sessions, activePersonID: activePersonID, trainingDays: days)
        let person = people.first { $0.id.uuidString == activePersonID } ?? people.first
        Reminders.reschedule(enabled: remindersOn, minutesOfDay: reminderMinutes,
                             trainingDays: days, person: person, sessions: sessions)
    }
}

/// Shared "who's lifting" switcher shown at the top of each tab when there's more than one person.
struct PersonPicker: View {
    @Query(sort: \Person.createdAt) private var people: [Person]
    @AppStorage("activePersonID") private var activePersonID = ""

    var body: some View {
        if people.count > 1 {
            Picker("Who's lifting", selection: $activePersonID) {
                ForEach(people) { p in
                    Text(p.name).tag(p.id.uuidString)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
