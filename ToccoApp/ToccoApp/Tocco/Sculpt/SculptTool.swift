import Foundation

enum SculptTool: String, CaseIterable, Identifiable {
    case push
    case pull
    case smooth

    var id: String { rawValue }
}
