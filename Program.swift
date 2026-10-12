import SwiftUI

struct Exercise: Identifiable {
    let id: String
    let name: String
    let scheme: String
    /// false = bodyweight move; the weight box means "added weight"
    let weighted: Bool
}

struct WorkoutDay: Identifiable {
    let id: String
    let short: String
    let title: String
    let color: Color
    let exercises: [Exercise]
}

enum Program {
    static let days: [WorkoutDay] = [
        WorkoutDay(id: "d1", short: "Push", title: "Push + Core", color: .red, exercises: [
            Exercise(id: "bench", name: "Bench press (or DB press)", scheme: "4 × 6–8", weighted: true),
            Exercise(id: "ohp", name: "Overhead press", scheme: "3 × 8", weighted: true),
            Exercise(id: "incdb", name: "Incline dumbbell press", scheme: "3 × 10", weighted: true),
            Exercise(id: "pushdown", name: "Triceps pushdown", scheme: "3 × 10–12", weighted: true),
            Exercise(id: "hang", name: "Hanging knee / leg raise", scheme: "3 × 10–15", weighted: false),
        ]),
        WorkoutDay(id: "d2", short: "Pull", title: "Pull + Core", color: .blue, exercises: [
            Exercise(id: "pullup", name: "Pull-ups (or lat pulldown)", scheme: "4 × 6–8", weighted: true),
            Exercise(id: "row", name: "Barbell or cable row", scheme: "4 × 8", weighted: true),
            Exercise(id: "facepull", name: "Face pull", scheme: "3 × 12–15", weighted: true),
            Exercise(id: "curl", name: "Biceps curl", scheme: "3 × 10–12", weighted: true),
            Exercise(id: "plank", name: "Plank", scheme: "3 × 30–60 s", weighted: false),
        ]),
        WorkoutDay(id: "d3", short: "Legs", title: "Legs + Core", color: .orange, exercises: [
            Exercise(id: "squat", name: "Squat (or leg press)", scheme: "4 × 6–8", weighted: true),
            Exercise(id: "rdl", name: "Romanian deadlift", scheme: "3 × 8", weighted: true),
            Exercise(id: "lunge", name: "Walking lunge", scheme: "3 × 10 / leg", weighted: true),
            Exercise(id: "abwheel", name: "Ab wheel or cable crunch", scheme: "3 × 10–12", weighted: true),
            Exercise(id: "sideplank", name: "Side plank", scheme: "3 × 30 s / side", weighted: false),
        ]),
        WorkoutDay(id: "d4", short: "Upper", title: "Upper Strength", color: .green, exercises: [
            Exercise(id: "dips", name: "Weighted dips or close-grip bench", scheme: "3 × 8", weighted: true),
            Exercise(id: "chin", name: "Chin-ups", scheme: "3 × max", weighted: true),
            Exercise(id: "dbohp", name: "Dumbbell shoulder press", scheme: "3 × 10", weighted: true),
            Exercise(id: "dbrow", name: "Dumbbell row", scheme: "3 × 10 / arm", weighted: true),
            Exercise(id: "lateral", name: "Lateral raise", scheme: "3 × 12–15", weighted: true),
            Exercise(id: "carry", name: "Farmer's carry", scheme: "3 × 30–40 s", weighted: true),
        ]),
    ]

    static func day(_ id: String) -> WorkoutDay {
        days.first { $0.id == id } ?? days[0]
    }
}

// MARK: - Small helpers

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

func formatWeight(_ value: Double?) -> String {
    guard let v = value else { return "" }
    return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}
