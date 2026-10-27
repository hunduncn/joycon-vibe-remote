import SwiftUI
import JoyConVibeCore

struct StatusMenuView: View {
    static let panelWidth: CGFloat = 360
    static let initialHeight: CGFloat = 200
    private static let footerHeight: CGFloat = 40

    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    let onPreferredHeightChange: (CGFloat) -> Void

    @State private var panelHeight = Self.initialHeight

    init(
        model: AppModel,
        settings: RemoteSettings,
        onPreferredHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.model = model
        self.settings = settings
        self.onPreferredHeightChange = onPreferredHeightChange
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header

                if !model.accessibilityTrusted {
                    NoticeCard(
                        tint: .orange,
                        systemImage: "lock.trianglebadge.exclamationmark",
                        message: "需要辅助功能权限才能输出鼠标和键盘事件。"
                    ) {
                        Button("授予辅助功能权限") { model.requestAccessibility() }
                    }
                }
                if let error = model.errorMessage {
                    NoticeCard(tint: .red, systemImage: "exclamationmark.triangle", message: error) {
                        Button("重新连接") { model.reconnect() }
                        Button("输入监控设置") { model.openInputMonitoringSettings() }
                        Button("蓝牙设置") { model.openBluetoothSettings() }
                    }
                }
                if let message = model.loginItemMessage {
                    NoticeCard(tint: .orange, systemImage: "clock.badge.exclamationmark", message: message)
                }

                HStack(spacing: 8) {
                    shortcut("体感调节", systemImage: "gyroscope", page: .motion)
                    shortcut("按键映射", systemImage: "keyboard", page: .mapping)
                    shortcut("通用", systemImage: "gearshape", page: .general)
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

            Divider()
            footer.frame(height: Self.footerHeight)
        }
        .frame(width: Self.panelWidth, height: panelHeight, alignment: .top)
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
                .foregroundStyle(model.status.color)
                .frame(width: 36, height: 36)
                .background(model.status.color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(model.status.title).font(.headline)
                Text(model.statusDetail).font(.caption).foregroundStyle(.secondary)
                if let standby = model.standbyLine {
                    Text(standby).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            if model.batteryLevel > 0 {
                Label("\(model.batteryLevel * 25)%", systemImage: model.batterySymbol)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "启用 Joy-Con 遥控",
                isOn: Binding(get: { settings.enabled }, set: { model.setRemoteEnabled($0) })
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("启用或暂停 Joy-Con 遥控")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func shortcut(_ title: String, systemImage: String, page: SettingsPage) -> some View {
        Button {
            model.openSettings(page)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 16))
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Palette.cell, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("打开设置…") { model.openSettings(.status) }
            Spacer()
            Button("蓝牙设置") { model.openBluetoothSettings() }
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .padding(.horizontal, 16)
    }
}

enum StatusPanelHeightPolicy {
    static let minimumHeight: CGFloat = 140
    static let maximumHeight: CGFloat = 720

    static func height(for contentHeight: CGFloat) -> CGFloat {
        min(max(ceil(contentHeight), minimumHeight), maximumHeight)
    }
}

private struct PanelContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
