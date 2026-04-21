import Foundation

public enum TransferFunction: String, CaseIterable, Sendable {
    case rec709SDR
    case rec709HLG

    public var displayName: String {
        switch self {
        case .rec709SDR:
            return "Rec.709 SDR"
        case .rec709HLG:
            return "Rec.709 HLG"
        }
    }
}
