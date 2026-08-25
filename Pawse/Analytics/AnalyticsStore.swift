import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AnalyticsStore: SessionRecording {
    private(set) var records: [SessionRecordSnapshot] = []
    private(set) var errorMessage: LocalizedStringResource?

    @ObservationIgnored private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        reload()
    }

    func record(_ session: SessionRecordSnapshot) {
        guard !records.contains(where: { $0.id == session.id }) else { return }
        context.insert(SessionRecord(snapshot: session))
        do {
            try context.save()
            records.append(session)
            records.sort { $0.endedAt > $1.endedAt }
            errorMessage = nil
        } catch {
            context.rollback()
            errorMessage = "Session history could not be saved: \(error.localizedDescription)"
        }
    }

    func clear() {
        do {
            let storedRecords = try context.fetch(FetchDescriptor<SessionRecord>())
            for record in storedRecords {
                context.delete(record)
            }
            try context.save()
            records.removeAll()
            errorMessage = nil
        } catch {
            context.rollback()
            reload()
            errorMessage = "Session history could not be cleared: \(error.localizedDescription)"
        }
    }

    func reload() {
        do {
            records = try context.fetch(FetchDescriptor<SessionRecord>())
                .map(\.snapshot)
                .sorted { $0.endedAt > $1.endedAt }
            errorMessage = nil
        } catch {
            records = []
            errorMessage = "Session history could not be loaded: \(error.localizedDescription)"
        }
    }
}
