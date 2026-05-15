import Foundation
import QuartzCore

struct SculptProfiler {
    static func measure(_ operation: () -> Void) -> Double {
        let start = CACurrentMediaTime()
        operation()
        let end = CACurrentMediaTime()
        return (end - start) * 1000
    }
}
