import SwiftUI
import JoyConVibeCore

enum Palette {
    static let card = Color(nsColor: .controlBackgroundColor)
    static let cell = Color.primary.opacity(0.05)
    static let hairline = Color.primary.opacity(0.08)
    static let pink = Color(red: 0.89, green: 0.31, blue: 0.56)
    static let pinkFill = Color(red: 0.89, green: 0.31, blue: 0.56).opacity(0.10)
}

struct SettingsCard<Content: View>: View {
    var title: String?
    var padding: CGFloat = 18
    /// Stretch to the height offered by the parent, for cards laid out side
    /// by side that should line up.
    var fillsHeight = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline))
    }
}

struct StatusPill: View {
    enum Tone { case good, warning, neutral }
    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(foreground.opacity(0.13), in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .good: return .green
        case .warning: return .orange
        case .neutral: return .secondary
        }
    }
}

/// A rounded key label in the controller's accent colour.
struct KeyCap: View {
    let label: String
    var systemImage: String?
    var isHighlighted = false

    var body: some View {
        Group {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            } else {
                Text(label).font(.system(size: 11.5, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(isHighlighted ? Color.white : Palette.pink)
        .frame(minWidth: 24, minHeight: 22)
        .padding(.horizontal, 5)
        .background(isHighlighted ? Color.accentColor : Palette.pinkFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isHighlighted ? Color.accentColor : Palette.pink, lineWidth: 1.5)
        )
        .accessibilityHidden(true)
    }
}

struct NoticeCard<Actions: View>: View {
    let tint: Color
    let systemImage: String
    let message: String
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 7) {
                Text(message)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    actions
                }
                .controlSize(.small)
            }
        }
        .font(.caption)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension NoticeCard where Actions == EmptyView {
    init(tint: Color, systemImage: String, message: String) {
        self.init(tint: tint, systemImage: systemImage, message: message) { EmptyView() }
    }
}

/// A slider that snaps to `step`, marks its default value and reports the
/// start and end of a drag, so tuning is committed once per gesture.
struct TuningSlider: View {
    let title: String
    let detail: String
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double
    var format: (Double) -> String = { String(format: "%.2f", $0) }
    var lowerLabel: String?
    let onValueChanged: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    @State private var value: Double
    @State private var isDragging = false

    init(
        title: String,
        detail: String,
        initialValue: Double,
        range: ClosedRange<Double>,
        step: Double,
        defaultValue: Double,
        format: @escaping (Double) -> String = { String(format: "%.2f", $0) },
        lowerLabel: String? = nil,
        onValueChanged: @escaping (Double) -> Void,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.detail = detail
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.format = format
        self.lowerLabel = lowerLabel
        self.onValueChanged = onValueChanged
        self.onEditingChanged = onEditingChanged
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(format(value))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Palette.cell, in: RoundedRectangle(cornerRadius: 6))
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12)).frame(height: 6)
                    Capsule().fill(Color.accentColor).frame(width: max(6, width * fraction(value)), height: 6)
                    Capsule()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 2, height: 14)
                        .offset(x: width * fraction(defaultValue) - 1)
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.08)))
                        .frame(width: 20, height: 20)
                        .offset(x: width * fraction(value) - 10)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if !isDragging {
                                isDragging = true
                                onEditingChanged(true)
                            }
                            update(toFraction: drag.location.x / max(width, 1))
                        }
                        .onEnded { _ in
                            isDragging = false
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: 20)
            HStack {
                Text(lowerLabel ?? format(range.lowerBound))
                Spacer()
                Text(format(range.upperBound))
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? step : -step
            onEditingChanged(true)
            set(value + delta)
            onEditingChanged(false)
        }
    }

    private func fraction(_ v: Double) -> CGFloat {
        CGFloat((v - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func update(toFraction f: CGFloat) {
        let clamped = min(max(Double(f), 0), 1)
        set(range.lowerBound + clamped * (range.upperBound - range.lowerBound))
    }

    private func set(_ raw: Double) {
        let snapped = min(max((raw / step).rounded() * step, range.lowerBound), range.upperBound)
        guard abs(snapped - value) > step / 10 else { return }
        value = snapped
        onValueChanged(snapped)
    }
}

/// A borderless pop-up that shows only its current value, so a table of
/// mappings reads as text rather than as a wall of buttons.
struct ActionMenu<Action: Hashable>: View {
    let caption: String?
    let selection: Action
    let choices: [Action]
    let title: (Action) -> String
    let isDimmed: (Action) -> Bool
    let onSelect: (Action) -> Void

    var body: some View {
        Menu {
            Picker("", selection: Binding(get: { selection }, set: onSelect)) {
                ForEach(choices, id: \.self) { action in
                    Text(title(action)).tag(action)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            VStack(spacing: 1) {
                if let caption {
                    Text(caption).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    Text(title(selection))
                        .font(.system(size: 13, weight: isDimmed(selection) ? .regular : .semibold))
                        .foregroundStyle(isDimmed(selection) ? .tertiary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Palette.cell, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

extension RemoteStatus {
    var color: Color {
        switch self {
        case .precision: return .purple
        case .active: return .blue
        case .connected: return .green
        case .paused, .disconnected: return .secondary
        case .calibrating, .initializing: return .orange
        case .error: return .red
        }
    }
}

extension AppModel {
    var statusDetail: String {
        switch status {
        case let .calibrating(progress):
            return "静置约 1 秒 · \(Int(progress * 100))%"
        case .disconnected:
            return "请配对并唤醒 Joy-Con (R)"
        default:
            return deviceName
        }
    }

    var batterySymbol: String {
        if isCharging { return "battery.100percent.bolt" }
        switch batteryLevel {
        case 4: return "battery.100percent"
        case 3: return "battery.75percent"
        case 2: return "battery.50percent"
        default: return "battery.25percent"
        }
    }

    /// Calibration progress in 0...1, or nil when no controller is connected.
    var calibrationProgress: Double? {
        guard isConnected else { return nil }
        switch status {
        case let .calibrating(progress): return progress
        case .initializing, .disconnected: return 0
        default: return 1
        }
    }
}

extension JoyConButton {
    var mappingTitle: String {
        switch self {
        case .r: return "R"
        case .zr: return "ZR"
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .plus: return "+"
        case .home: return "Home"
        case .stick: return "摇杆按下"
        case .sr: return "SR"
        case .sl: return "SL"
        }
    }
}

extension RemoteButtonAction {
    var mappingTitle: String {
        switch self {
        case .usePrimary: return "同单按"
        case .none: return "无操作"
        case .function: return "Fn（单击）"
        case .returnKey: return "回车"
        case .space: return "空格"
        case .tab: return "Tab"
        case .deleteBackward: return "删除（可长按）"
        case .escape: return "Esc"
        case .leftArrow: return "方向键 ←"
        case .rightArrow: return "方向键 →"
        case .upArrow: return "方向键 ↑"
        case .downArrow: return "方向键 ↓"
        case .commandModifier: return "Command（按住）"
        case .optionModifier: return "Option（按住）"
        case .controlModifier: return "Control（按住）"
        case .shiftModifier: return "Shift（按住）"
        case .leftClick: return "鼠标左键"
        case .rightClick: return "鼠标右键"
        case .switchApplication: return "切换应用"
        case .showStatus: return "显示面板"
        case .newLine: return "换行（不发送）"
        case .interrupt: return "强制中断"
        case .reverseTab: return "Shift+Tab"
        case .commandSymbols: return "循环 / @ $ !"
        }
    }
}

extension RemoteStickVerticalAction {
    var mappingTitle: String {
        switch self {
        case .usePrimary: return "同单按"
        case .none: return "无操作"
        case .scroll: return "滚动"
        case .arrowKeys: return "方向键 ↑ ↓"
        }
    }
}
