import JoyConVibeCore

/// What each logical button is called on the controller in hand. A left
/// controller reports its buttons as the right ones in the mirrored spot,
/// so only the names shown to the user differ.
extension JoyConSide {
    var displayName: String {
        switch self {
        case .right: return "右手柄"
        case .left: return "左手柄"
        }
    }

    func keyLabel(_ button: JoyConButton) -> String {
        guard self == .left else { return button.mappingTitle }
        switch button {
        case .zr: return "ZL"
        case .r: return "L"
        case .a: return "←"
        case .y: return "→"
        case .x: return "↑"
        case .b: return "↓"
        case .plus: return "−"
        case .home: return "截图"
        case .stick: return "摇杆按下"
        case .sl: return "SR"
        case .sr: return "SL"
        }
    }

    func partName(_ part: JoyConPart) -> String {
        switch part {
        case .plus: return self == .right ? "加号键" : "减号键"
        case .sr, .sl: return "侧键 \(keyLabel(part.button))"
        case .zr: return "扳机 \(keyLabel(.zr))"
        case .r: return "肩键 \(keyLabel(.r))"
        case .home: return self == .right ? "Home 键" : "截图键"
        case .stick: return "摇杆"
        case .x, .y, .a, .b: return "\(keyLabel(part.button)) 键"
        }
    }
}
