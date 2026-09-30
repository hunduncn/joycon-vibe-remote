import SwiftUI
import JoyConVibeCore

struct StatusMenuView: View {
    static let panelWidth: CGFloat = 420
    static let initialHeight: CGFloat = 360
    private static let footerHeight: CGFloat = 40

    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    let onPreferredHeightChange: (CGFloat) -> Void

    @State private var tuningExpanded: Bool
    @State private var mappingsExpanded: Bool
    @State private var panelHeight = Self.initialHeight

    init(
        model: AppModel,
        settings: RemoteSettings,
        tuningExpanded: Bool = false,
        mappingsExpanded: Bool = true,
        onPreferredHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.model = model
        self.settings = settings
        self.onPreferredHeightChange = onPreferredHeightChange
        _tuningExpanded = State(initialValue: tuningExpanded)
        _mappingsExpanded = State(initialValue: mappingsExpanded)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header

                    if !model.accessibilityTrusted {
                        permissionNotice
                    }
                    if let error = model.errorMessage {
                        errorNotice(error)
                    }
                    if let message = model.loginItemMessage {
                        NoticeCard(tint: .orange, systemImage: "clock.badge.exclamationmark", message: message)
                    }

                    SectionCard(
                        title: "体感调节",
                        systemImage: "gyroscope",
                        isExpanded: $tuningExpanded
                    ) {
                        pointerControls
                    }

                    SectionCard(
                        title: "按键自定义",
                        systemImage: "slider.horizontal.3",
                        isExpanded: $mappingsExpanded,
                        accessory: {
                            Button("恢复默认") { settings.resetButtonMappings() }
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                    ) {
                        mappingGrid
                    }
                }
                .padding(12)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: PanelContentHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                }
            }

            Divider()
            // Pinned outside the scroll view so quitting never needs scrolling.
            footer
                .frame(height: Self.footerHeight)
        }
        .frame(width: Self.panelWidth, height: panelHeight)
        .onPreferenceChange(PanelContentHeightPreferenceKey.self) { contentHeight in
            let preferredHeight = StatusPanelHeightPolicy.height(
                for: contentHeight + Self.footerHeight + 1
            )
            guard abs(preferredHeight - panelHeight) > 0.5 else { return }
            panelHeight = preferredHeight
            onPreferredHeightChange(preferredHeight)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: model.status.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(model.status.title)
                    .font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if model.batteryLevel > 0 {
                Label("\(model.batteryLevel * 25)%", systemImage: batterySymbol)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "启用 Joy-Con 遥控",
                isOn: Binding(
                    get: { settings.enabled },
                    set: { model.setRemoteEnabled($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("启用或暂停 Joy-Con 遥控")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var permissionNotice: some View {
        NoticeCard(
            tint: .orange,
            systemImage: "lock.trianglebadge.exclamationmark",
            message: "需要辅助功能权限才能输出鼠标和键盘事件。"
        ) {
            Button("授予辅助功能权限") { model.requestAccessibility() }
        }
    }

    private func errorNotice(_ message: String) -> some View {
        NoticeCard(tint: .red, systemImage: "exclamationmark.triangle", message: message) {
            Button("重新连接") { model.reconnect() }
            Button("输入监控设置") { model.openInputMonitoringSettings() }
            Button("蓝牙设置") { model.openBluetoothSettings() }
        }
    }

    private var pointerControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            TuningSliderRow(
                title: "整体灵敏度",
                initialValue: settings.sensitivity,
                range: 0.25...4,
                step: 0.05,
                onValueChanged: { settings.sensitivity = $0 },
                onEditingChanged: model.setPointerTuningEditing
            )
            TuningSliderRow(
                title: "水平倍率",
                initialValue: settings.horizontalSensitivityMultiplier,
                range: 0.75...2.50,
                step: 0.05,
                onValueChanged: { settings.horizontalSensitivityMultiplier = $0 },
                onEditingChanged: model.setPointerTuningEditing
            )
            TuningSliderRow(
                title: "加速度",
                initialValue: settings.accelerationStrength,
                range: 0...2,
                step: 0.05,
                onValueChanged: { settings.accelerationStrength = $0 },
                onEditingChanged: model.setPointerTuningEditing
            )
            TuningSliderRow(
                title: "稳定度",
                initialValue: settings.stabilizationStrength,
                range: 0...2,
                step: 0.05,
                onValueChanged: { settings.stabilizationStrength = $0 },
                onEditingChanged: model.setPointerTuningEditing
            )
            TuningSliderRow(
                title: "精准比例",
                initialValue: settings.precisionMultiplier,
                range: 0.10...0.60,
                step: 0.05,
                display: .percent,
                onValueChanged: { settings.precisionMultiplier = $0 },
                onEditingChanged: model.setPointerTuningEditing
            )

            PointerDirectionRow(settings: settings) {
                model.recalibrate()
            }
        }
    }

    private var mappingGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: PanelMetrics.mappingSpacing) {
                Text("按键")
                    .frame(width: PanelMetrics.mappingLabelWidth, alignment: .leading)
                Text("单按")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("按住 SL")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, PanelMetrics.rowPadding)
            .padding(.bottom, 2)

            ForEach(RemoteButtonAction.configurableButtons, id: \.self) { button in
                MappingRow(label: button.mappingTitle) {
                    ActionMenu(
                        selection: settings.binding(for: button).primary,
                        choices: RemoteButtonAction.primaryChoices,
                        title: \.mappingTitle,
                        isDimmed: { $0 == .none },
                        onSelect: { settings.setPrimaryMapping($0, for: button) }
                    )
                } withSL: {
                    ActionMenu(
                        selection: settings.binding(for: button).withSL,
                        choices: RemoteButtonAction.slChoices,
                        title: \.mappingTitle,
                        isDimmed: { $0 == .usePrimary || $0 == .none },
                        onSelect: { settings.setSLMapping($0, for: button) }
                    )
                }
            }

            MappingRow(label: "摇杆上下") {
                ActionMenu(
                    selection: settings.stickVerticalBinding.primary,
                    choices: RemoteStickVerticalAction.primaryChoices,
                    title: \.mappingTitle,
                    isDimmed: { $0 == .none },
                    onSelect: { settings.setStickVerticalPrimary($0) }
                )
            } withSL: {
                ActionMenu(
                    selection: settings.stickVerticalBinding.withSL,
                    choices: RemoteStickVerticalAction.slChoices,
                    title: \.mappingTitle,
                    isDimmed: { $0 == .usePrimary || $0 == .none },
                    onSelect: { settings.setStickVerticalSL($0) }
                )
            }

            Text("固定：ZR 体感 · ZR + SL 精准体感 · 摇杆左右 ← →")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, PanelMetrics.rowPadding)
                .padding(.top, 6)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Toggle(
                "登录时启动",
                isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Spacer()
            Button("蓝牙设置") { model.openBluetoothSettings() }
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .padding(.horizontal, 16)
    }

    private var statusDetail: String {
        switch model.status {
        case let .calibrating(progress):
            return "静置约 1 秒 · \(Int(progress * 100))%"
        case .disconnected:
            return "请配对并唤醒 Joy-Con (R)"
        default:
            return model.deviceName
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .precision: return .purple
        case .active: return .blue
        case .connected: return .green
        case .paused: return .secondary
        case .calibrating, .initializing: return .orange
        case .error: return .red
        case .disconnected: return .secondary
        }
    }

    private var batterySymbol: String {
        if model.isCharging { return "battery.100percent.bolt" }
        switch model.batteryLevel {
        case 4: return "battery.100percent"
        case 3: return "battery.75percent"
        case 2: return "battery.50percent"
        default: return "battery.25percent"
        }
    }
}

enum StatusPanelHeightPolicy {
    static let minimumHeight: CGFloat = 220
    static let maximumHeight: CGFloat = 720

    static func height(for contentHeight: CGFloat) -> CGFloat {
        min(max(ceil(contentHeight), minimumHeight), maximumHeight)
    }
}

private enum PanelMetrics {
    static let rowPadding: CGFloat = 6
    static let mappingLabelWidth: CGFloat = 66
    static let mappingSpacing: CGFloat = 8
}

private struct PanelContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SectionCard<Accessory: View, Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    accessory
                }

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 14, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起\(title)" : "展开\(title)")
            }
            .padding(.horizontal, PanelMetrics.rowPadding)

            if isExpanded {
                content
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

extension SectionCard where Accessory == EmptyView {
    init(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            isExpanded: isExpanded,
            accessory: { EmptyView() },
            content: content
        )
    }
}

private struct NoticeCard<Actions: View>: View {
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
        .background(
            tint.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

extension NoticeCard where Actions == EmptyView {
    init(tint: Color, systemImage: String, message: String) {
        self.init(tint: tint, systemImage: systemImage, message: message) { EmptyView() }
    }
}

private struct HoverRow<Content: View>: View {
    @State private var isHovering = false
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, PanelMetrics.rowPadding)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}

private struct MappingRow<Primary: View, WithSL: View>: View {
    let label: String
    @ViewBuilder let primary: Primary
    @ViewBuilder let withSL: WithSL

    var body: some View {
        HoverRow {
            HStack(spacing: PanelMetrics.mappingSpacing) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .frame(width: PanelMetrics.mappingLabelWidth, alignment: .leading)
                primary
                    .frame(maxWidth: .infinity, alignment: .leading)
                withSL
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// A borderless pop-up that shows only its current value, so a table of
/// mappings reads as text rather than as a wall of buttons.
private struct ActionMenu<Action: Hashable>: View {
    let selection: Action
    let choices: [Action]
    let title: (Action) -> String
    let isDimmed: (Action) -> Bool
    let onSelect: (Action) -> Void

    var body: some View {
        Menu {
            Picker(
                "",
                selection: Binding(get: { selection }, set: onSelect)
            ) {
                ForEach(choices, id: \.self) { action in
                    Text(title(action)).tag(action)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 4) {
                Text(title(selection))
                    .font(.callout)
                    .foregroundStyle(isDimmed(selection) ? .tertiary : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

private struct TuningSliderRow: View {
    enum Display {
        case decimal
        case percent
    }

    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let display: Display
    let onValueChanged: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    @State private var value: Double

    init(
        title: String,
        initialValue: Double,
        range: ClosedRange<Double>,
        step: Double,
        display: Display = .decimal,
        onValueChanged: @escaping (Double) -> Void,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.range = range
        self.step = step
        self.display = display
        self.onValueChanged = onValueChanged
        self.onEditingChanged = onEditingChanged
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 66, alignment: .leading)
            // Snapping here instead of passing `step:` keeps the track free of
            // the dozens of tick marks AppKit draws for a stepped slider.
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        let snapped = (newValue / step).rounded() * step
                        guard snapped != value else { return }
                        value = snapped
                        onValueChanged(snapped)
                    }
                ),
                in: range,
                onEditingChanged: onEditingChanged
            )
            .controlSize(.small)
            valueLabel
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .font(.callout)
        .padding(.horizontal, PanelMetrics.rowPadding)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var valueLabel: some View {
        switch display {
        case .decimal:
            Text(value, format: .number.precision(.fractionLength(2)))
        case .percent:
            Text(value, format: .percent.precision(.fractionLength(0)))
        }
    }
}

private struct PointerDirectionRow: View {
    let settings: RemoteSettings
    let recalibrate: () -> Void

    @State private var invertHorizontal: Bool
    @State private var invertVertical: Bool

    init(settings: RemoteSettings, recalibrate: @escaping () -> Void) {
        self.settings = settings
        self.recalibrate = recalibrate
        _invertHorizontal = State(initialValue: settings.invertHorizontal)
        _invertVertical = State(initialValue: settings.invertVertical)
    }

    var body: some View {
        HStack(spacing: 14) {
            Toggle(
                "水平反向",
                isOn: Binding(
                    get: { invertHorizontal },
                    set: { newValue in
                        invertHorizontal = newValue
                        settings.invertHorizontal = newValue
                    }
                )
            )
            Toggle(
                "垂直反向",
                isOn: Binding(
                    get: { invertVertical },
                    set: { newValue in
                        invertVertical = newValue
                        settings.invertVertical = newValue
                    }
                )
            )
            Spacer()
            Button("重新校准", action: recalibrate)
                .buttonStyle(.borderless)
        }
        .toggleStyle(.checkbox)
        .controlSize(.small)
        .font(.caption)
        .padding(.horizontal, PanelMetrics.rowPadding)
        .padding(.top, 6)
    }
}

private extension JoyConButton {
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

private extension RemoteButtonAction {
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

private extension RemoteStickVerticalAction {
    var mappingTitle: String {
        switch self {
        case .usePrimary: return "同单按"
        case .none: return "无操作"
        case .scroll: return "滚动"
        case .arrowKeys: return "方向键 ↑ ↓"
        }
    }
}
