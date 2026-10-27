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
        case .mapping: return "每个按键有「单按」和「按住副层键」两层动作，点击动作即可修改"
        case .general: return "启动、权限和关于"
        }
    }

    /// The height below which the page scrolls instead of squeezing.
    var minimumContentHeight: CGFloat {
        switch self {
        case .status: return 470
        case .motion: return 430
        case .mapping: return 470
        case .general: return 430
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
    /// Preferred size; the window shrinks to fit smaller screens.
    static let size = CGSize(width: 860, height: 580)
    static let minimumSize = CGSize(width: 840, height: 540)

    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                // Pages fill a large window and scroll in a short one, such as
                // a 13-inch laptop with the Dock showing.
                GeometryReader { proxy in
                    ScrollView(.vertical) {
                        Group {
                            switch navigation.page {
                            case .status: StatusPage(model: model, settings: settings, liveInput: model.liveInput)
                            case .motion: MotionPage(model: model, settings: settings)
                            case .mapping: MappingPage(model: model, settings: settings, highlight: model.pressHighlight)
                            case .general: GeneralPage(model: model, settings: settings)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .frame(
                            width: proxy.size.width,
                            height: max(navigation.page.minimumContentHeight, proxy.size.height),
                            alignment: .top
                        )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(spacing: 4) {
            ForEach(SettingsPage.allCases) { page in
                let selected = navigation.page == page
                Button {
                    navigation.page = page
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 16, weight: .regular))
                            .frame(height: 20)
                        Text(page.title).font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                    }
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected ? Color.accentColor.opacity(0.12) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 44)
        .frame(width: 84)
        .background(Color.primary.opacity(0.03))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(navigation.page.title).font(.system(size: 20, weight: .bold))
                Text(navigation.page.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            DeviceBadge(model: model)
        }
    }
}

private struct DeviceBadge: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.isConnected ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.deviceName).font(.system(size: 12.5, weight: .semibold))
                HStack(spacing: 4) {
                    Text(model.isConnected ? "已连接" : model.status == .sleeping ? "已休眠" : "未连接")
                        .fontWeight(.semibold)
                        .foregroundStyle(model.isConnected ? Color.green : Color.secondary)
                    if model.isConnected, model.batteryLevel > 0 {
                        Text("· 电量 \(model.batteryLevel * 25)%").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 10.5))
                if let standby = model.standbyLine {
                    Text(standby).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(model.isConnected ? Color.accentColor.opacity(0.35) : Palette.hairline)
        )
    }
}
