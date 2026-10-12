import SwiftUI
import SwiftData

@main
struct GymLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Person.self, Session.self, WeightEntry.self, BodyWeight.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.createdAt) private var people: [Person]
    @AppStorage("activePersonID") private var activePersonID = ""

    var body: some View {
        TabView {
            WorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell") }
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
        }
        .onChange(of: people.map(\.id)) { _, ids in
            if !ids.contains(where: { $0.uuidString == activePersonID }), let first = ids.first {
                activePersonID = first.uuidString
            }
        }
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
