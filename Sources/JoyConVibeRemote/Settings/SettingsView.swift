import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case status, motion, mapping, general

    var id: Self { self }

    var title: String {
        switch self {
        case .status: return "状态"
        case .motion: return "体感调节"
        case .mapping: return "按键映射"
        case .general: return "通用"
        }
    }

    var subtitle: String {
        switch self {
        case .status: return "连接、校准与权限一览，出问题时先看这里"
        case .motion: return "按住 ZR 转动手腕移动光标；调好后，下一次按下 ZR 生效"
        case .mapping: return "每个按键有「单按」和「按住 SL」两层动作，点击动作即可修改"
        case .general: return "启动、权限和关于"
        }
    }

    var systemImage: String {
        switch self {
        case .status: return "gamecontroller"
        case .motion: return "gyroscope"
        case .mapping: return "keyboard"
        case .general: return "gearshape"
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage = .status
}

struct SettingsView: View {
    static let size = CGSize(width: 1180, height: 880)

    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 30)
                    .padding(.top, 30)
                    .padding(.bottom, 18)
                Group {
                    switch navigation.page {
                    case .status: StatusPage(model: model, settings: settings, liveInput: model.liveInput)
                    case .motion: MotionPage(model: model, settings: settings)
                    case .mapping: MappingPage(model: model, settings: settings, highlight: model.pressHighlight)
                    case .general: GeneralPage(model: model, settings: settings)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 4) {
            ForEach(SettingsPage.allCases) { page in
                let selected = navigation.page == page
                Button {
                    navigation.page = page
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 20, weight: .regular))
                            .frame(height: 24)
                        Text(page.title).font(.system(size: 12, weight: selected ? .semibold : .regular))
                    }
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selected ? Color.accentColor.opacity(0.12) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 56)
        .frame(width: 150)
        .background(Color.primary.opacity(0.03))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(navigation.page.title).font(.system(size: 26, weight: .bold))
                Text(navigation.page.subtitle).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            Spacer()
            DeviceBadge(model: model)
        }
    }
}

private struct DeviceBadge: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isConnected ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.deviceName).font(.system(size: 14, weight: .semibold))
                HStack(spacing: 4) {
                    Text(model.isConnected ? "已连接" : "未连接")
                        .fontWeight(.semibold)
                        .foregroundStyle(model.isConnected ? Color.green : Color.secondary)
                    if model.isConnected, model.batteryLevel > 0 {
                        Text("· 电量 \(model.batteryLevel * 25)%").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(model.isConnected ? Color.accentColor.opacity(0.35) : Palette.hairline)
        )
    }
}
