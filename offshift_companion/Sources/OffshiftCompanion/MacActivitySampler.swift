import CoreGraphics
import Foundation
import OffshiftCompanionCore

/// A local-only sampler. It records no keystrokes, app titles, prompts, code, or window data.
@MainActor
final class MacActivitySampler {
    var onIntervalsChanged: (([ActiveAppInterval]) -> Void)?
    private(set) var isSampling = false
    private var intervals: [ActiveAppInterval] = []
    private var timer: Timer?
    private var lastSampleAt = Date.now

    func start() {
        guard !isSampling else { return }
        isSampling = true
        lastSampleAt = .now
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleNow() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isSampling = false
    }

    func sampleNow(at now: Date = .now, idleDuration: TimeInterval? = nil) {
        let sampleDuration = now.timeIntervalSince(lastSampleAt)
        lastSampleAt = now
        // CoreGraphics exposes the C API's any-input sentinel as a raw event type.
        // It yields only elapsed idle seconds, not the underlying input events.
        let anyInputEvent = CGEventType(rawValue: UInt32.max)!
        let idle = idleDuration ?? CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEvent)
        if let interval = AggregateActivityIntervalFactory.make(
            endingAt: now,
            sampleDuration: sampleDuration,
            idleDuration: idle
        ) {
            intervals.append(interval)
        }
        let lowerBound = now.addingTimeInterval(-2 * 60 * 60)
        intervals.removeAll { $0.startedAt < lowerBound }
        onIntervalsChanged?(intervals)
    }
}
