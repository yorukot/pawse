import Foundation

protocol SessionClock: AnyObject {
    var now: Date { get }
}

final class SystemSessionClock: SessionClock {
    var now: Date { Date() }
}

@MainActor
protocol RepeatingScheduling: AnyObject {
    var isScheduled: Bool { get }
    func schedule(every interval: TimeInterval, action: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
final class TaskRepeatingScheduler: RepeatingScheduling {
    private var task: Task<Void, Never>?
    var isScheduled: Bool { task != nil }

    func schedule(every interval: TimeInterval, action: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                guard self != nil, !Task.isCancelled else { return }
                action()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
