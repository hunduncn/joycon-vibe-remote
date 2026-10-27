import AppKit
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @State private var confirmingReset = false

    private static let repository = URL(string: "https://github.com/hunduncn/joycon-vibe-remote")!
    private static let manual = URL(string: "https://hunduncn.github.io/joycon-vibe-remote/manual/")!

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 18) {
                SettingsCard(title: "启动") {
                    row(icon: "power", tint: .indigo, title: "登录时启动", detail: model.loginItemMessage ?? "开机后自动常驻菜单栏") {
                        Toggle("登录时启动", isOn: Binding(get: { settings.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
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
                    row(icon: "arrow.counterclockwise", tint: .gray, title: "恢复全部默认设置", detail: "按键映射和体感参数都会还原") {
                        Button("恢复默认…", role: .destructive) { confirmingReset = true }
                    }
                }
            }
            .frame(width: 480)

            about
        }
        .frame(maxHeight: 620, alignment: .top)
        .confirmationDialog("恢复全部默认设置？", isPresented: $confirmingReset) {
            Button("恢复默认", role: .destructive) { model.resetAllSettings() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("按键映射、体感参数和方向反转都会恢复为默认值，此操作无法撤销。")
        }
    }

    private var about: some View {
        SettingsCard(fillsHeight: true) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("退出 App", role: .destructive) { NSApplication.shared.terminate(nil) }
                }
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 150, height: 150)
                    .padding(.top, 10)
                Text("Joy-Con Vibe Remote").font(.system(size: 22, weight: .bold)).padding(.top, 6)
                Text("版本 \(Self.version)").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                Text("把 Nintendo Switch 右手 Joy-Con 变成 macOS 的体感鼠标与 Vibe Coding 遥控器。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 320)
                    .padding(.top, 16)
                VStack(spacing: 10) {
                    linkButton("在 GitHub 查看新版本") { NSWorkspace.shared.open(Self.repository.appendingPathComponent("releases")) }
                    linkButton("打开网页说明书") { NSWorkspace.shared.open(Self.manual) }
                    linkButton("第三方声明") { openNotices() }
                }
                .frame(width: 300)
                .padding(.top, 28)
                Spacer(minLength: 20)
                Text("Joy-Con 与 Nintendo Switch 是 Nintendo 的商标。\n本项目为独立开发工具，与 Nintendo 无隶属关系。")
                    .font(.system(size: 11))
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
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Palette.cell, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}
