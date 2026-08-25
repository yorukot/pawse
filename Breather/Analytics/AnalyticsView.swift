import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Sessions Yet",
            systemImage: "chart.bar",
            description: Text("Completed and interrupted sessions will appear here.")
        )
        .navigationTitle("Analytics")
    }
}

