import AppKit
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @State private var confirmingReset = false

    private static let repository = URL(string: "https://github.com/hunduncn/joycon-vibe-remote")!
    private static let manual = URL(string: "https://hunduncn.github.io/joycon-vibe-remote/manual/")!

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                SettingsCard(title: "启动与省电") {
                    row(icon: "power", tint: .indigo, title: "登录时启动", detail: model.loginItemMessage ?? "开机后自动常驻菜单栏") {
                        Toggle("登录时启动", isOn: Binding(get: { settings.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    Divider()
                    row(icon: "moon.zzz", tint: .purple, title: "闲置自动休眠", detail: "不用时让手柄断开蓝牙省电，按任意键唤醒") {
                        Picker("闲置自动休眠", selection: $settings.idleSleepMinutes) {
                            Text("关闭").tag(0)
                            Text("10 分钟").tag(10)
                            Text("30 分钟").tag(30)
                            Text("1 小时").tag(60)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        Button("立即休眠") { model.sleepController() }
                            .disabled(!model.isConnected)
                            .help("让所有已连接的手柄马上断开蓝牙休眠")
                    }
                }
                SettingsCard(title: "系统权限") {
                    row(icon: "accessibility", tint: .blue, title: "辅助功能", detail: "输出鼠标和键盘事件，必需") {
                        if model.accessibilityTrusted {
                            StatusPill(text: "已授权", tone: .good)
                        } else {
                            StatusPill(text: "未授权", tone: .warning)
                            Button("授权") { model.requestAccessibility() }
                        }
                    }
                    Divider()
                    row(icon: "keyboard", tint: .orange, title: "输入监控", detail: "读取手柄失败时才需要") {
                        switch model.inputMonitoringAccess {
                        case .granted:
                            StatusPill(text: "已授权", tone: .good)
                        case .denied:
                            StatusPill(text: "未授权", tone: .warning)
                            Button("打开设置") { model.openInputMonitoringSettings() }
                        case .undetermined:
                            StatusPill(text: "未请求", tone: .neutral)
                            Button("授权") { model.requestInputMonitoring() }
                        }
                    }
                    Divider()
                    row(icon: "dot.radiowaves.left.and.right", tint: .blue, title: "蓝牙", detail: "配对与重新连接 Joy-Con") {
                        Button("打开设置") { model.openBluetoothSettings() }
                    }
                }
                SettingsCard(title: "重置") {
                    row(icon: "arrow.counterclockwise", tint: .gray, title: "恢复全部默认设置", detail: "左右手柄的按键映射和体感参数都会还原") {
                        Button("恢复默认…", role: .destructive) { confirmingReset = true }
                    }
                }
            }
            .frame(minWidth: 330, maxWidth: 380)

            about
        }
        .frame(maxHeight: 440, alignment: .top)
        .confirmationDialog("恢复全部默认设置？", isPresented: $confirmingReset) {
            Button("恢复默认", role: .destructive) { model.resetAllSettings() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("左右两套按键映射、体感参数和方向反转都会恢复为默认值，此操作无法撤销。")
        }
    }

    private var about: some View {
        SettingsCard(fillsHeight: true) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("退出 App", role: .destructive) { NSApplication.shared.terminate(nil) }
                        .controlSize(.small)
                }
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 92, height: 92)
                Text("Joy-Con Vibe Remote").font(.system(size: 17, weight: .bold)).padding(.top, 4)
                Text("版本 \(Self.version)").font(.system(size: 10.5)).foregroundStyle(.secondary).padding(.top, 2)
                Text("把 Nintendo Switch Joy-Con（左手或右手）变成 macOS 的体感鼠标与 Vibe Coding 遥控器。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .padding(.top, 10)
                VStack(spacing: 6) {
                    linkButton("在 GitHub 查看新版本") { NSWorkspace.shared.open(Self.repository.appendingPathComponent("releases")) }
                    linkButton("打开网页说明书") { NSWorkspace.shared.open(Self.manual) }
                    linkButton("第三方声明") { openNotices() }
                }
                .frame(maxWidth: 230)
                .padding(.top, 14)
                Spacer(minLength: 10)
                Text("Joy-Con 与 Nintendo Switch 是 Nintendo 的商标。\n本项目为独立开发工具，与 Nintendo 无隶属关系。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    private func openNotices() {
        if let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(Self.repository.appendingPathComponent("blob/main/THIRD_PARTY_NOTICES.md"))
        }
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Palette.cell, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row<Trailing: View>(
        icon: String,
        tint: Color,
        title: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(detail).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 6)
            trailing()
                .controlSize(.small)
        }
    }
}
