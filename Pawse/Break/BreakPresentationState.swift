import Foundation
import Observation

@MainActor
@Observable
final class BreakPresentationState {
    enum Phase: Equatable, Sendable {
        case visible
        case discreetPreparing
        case discreetArmed
    }

    private(set) var phase: Phase = .visible
    private(set) var isBreakCommitted = false

    var isDiscreet: Bool {
        phase != .visible
    }

    var isInputArmed: Bool {
        phase == .discreetArmed
    }

    func beginBreakEntry() {
        phase = .visible
        isBreakCommitted = false
    }

    func commitBreak() {
        isBreakCommitted = true
    }

    func beginDiscreetMode() {
        guard isBreakCommitted else { return }
        phase = .discreetPreparing
    }

    func armDiscreetMode() {
        guard phase == .discreetPreparing else { return }
        phase = .discreetArmed
    }

    func revealBreak() {
        phase = .visible
    }

    func reset() {
        phase = .visible
        isBreakCommitted = false
    }
}
