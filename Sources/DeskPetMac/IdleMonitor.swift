import CoreGraphics
import Foundation

struct IdleMonitor {
    func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }
}
