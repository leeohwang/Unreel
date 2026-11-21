import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var rulesStore: RulesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(stats.today.totalBlocked)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Reels and Explore visits blocked today")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    LabeledContent("Time saved (estimate)", value: minutesText(saved(stats.today.totalBlocked)))
                    LabeledContent("Time in app today", value: minutesText(stats.today.secondsUsed / 60))
                } footer: {
                    Text("The estimate assumes each blocked visit would have cost about \(Int(rulesStore.rules.minutesPerBlockedVisit)) minutes of scrolling.")
                }

                Section("Last 7 days") {
                    Chart(stats.recentDays(7)) { item in
                        BarMark(
                            x: .value("Day", item.date, unit: .day),
                            y: .value("Blocked", item.stats.totalBlocked)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 8)
                }

                Section {
                    LabeledContent("Blocked all time", value: "\(stats.allTimeBlocked)")
                    LabeledContent("Time saved all time", value: minutesText(saved(stats.allTimeBlocked)))
                } footer: {
                    Text("These stats are stored only on this iPhone.")
                }
            }
            .navigationTitle("Your stats")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func saved(_ blocked: Int) -> Int {
        Int(Double(blocked) * rulesStore.rules.minutesPerBlockedVisit)
    }

    private func minutesText(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}
