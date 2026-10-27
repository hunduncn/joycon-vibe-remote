import SwiftUI
import JoyConVibeCore

struct StatusPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @ObservedObject var liveInput: LiveInput

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                hero.frame(minWidth: 320, maxWidth: 380).frame(height: 278)
                VStack(spacing: 10) {
                    calibration.frame(height: 112)
                    live.frame(height: 156)
                }
                .frame(minWidth: 336)
            }
            checklist
        }
        .onAppear { liveInput.isObserving = true }
        .onDisappear { liveInput.isObserving = false }
    }

    private var hero: some View {
        SettingsCard(padding: 0, fillsHeight: true) {
            HStack(alignment: .top, spacing: 16) {
                JoyConArtwork(side: model.activeSide ?? .right, highlighted: Set(liveInput.snapshot.buttons.map(JoyConPart.init)))
                    .frame(width: 96, height: 210)
                    .rotationEffect(.degrees(-8))
                    .padding(.leading, 20)
                    .padding(.top, 30)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        StatusIcon(model: model, diameter: 34, symbolSize: 15)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.status.title).font(.system(size: 17, weight: .bold))
                            Text(model.statusDetail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            if let standby = model.standbyLine {
                                Text(standby).font(.system(size: 10.5)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                        }
                    }

                    Text("电量").font(.system(size: 10.5)).foregroundStyle(.secondary).padding(.top, 16)
                    HStack(spacing: 8) {
                        ProgressView(value: Double(model.batteryLevel), total: 4)
                            .tint(model.batteryLevel <= 1 ? .orange : .green)
                        Text(model.isConnected && model.batteryLevel > 0 ? "\(model.batteryLevel * 25)%" : "—")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.top, 4)

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("启用 Joy-Con 遥控").font(.system(size: 12.5, weight: .semibold))
                            Text("关闭后按键和体感都不会输出").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Toggle("启用 Joy-Con 遥控", isOn: Binding(get: { settings.enabled }, set: { model.setRemoteEnabled($0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(10)
                    .background(Palette.cell, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 14)

                    HStack(spacing: 6) {
                        Button("重新连接") { model.reconnect() }
                        Button("蓝牙设置") { model.openBluetoothSettings() }
                    }
                    .controlSize(.small)
                    .padding(.top, 10)

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.red)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 22)
                .padding(.trailing, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RadialGradient(colors: [Color.accentColor.opacity(0.10), .clear], center: UnitPoint(x: 0.2, y: 0.45), startRadius: 0, endRadius: 200)
            )
        }
    }

    private var calibration: some View {
        let progress = model.calibrationProgress
        return SettingsCard(fillsHeight: true) {
            HStack {
                Text("零点校准").font(.system(size: 13, weight: .semibold))
                Spacer()
                switch progress {
                case nil: StatusPill(text: "未连接", tone: .neutral)
                case let value? where value >= 1: StatusPill(text: "✓ 已完成", tone: .good)
                default: StatusPill(text: "校准中", tone: .warning)
                }
            }
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.10), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress ?? 0)
                        .stroke((progress ?? 0) >= 1 ? Color.green : Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(progress.map { "\(Int($0 * 100))%" } ?? "—")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text("连接后静置约 1 秒自动完成；漂移或换握姿时可重新校准。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("重新校准") { model.recalibrate() }
                        .controlSize(.small)
                        .disabled(progress == nil)
                }
            }
        }
    }

    private var live: some View {
        let snapshot = liveInput.snapshot
        let keys: [JoyConButton] = [.zr, .r, .sr, .sl, .a, .b, .x, .y, .plus, .home, .stick]
        return SettingsCard(fillsHeight: true) {
            HStack {
                Text("实时输入").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("按下的键会亮起").font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 5), count: 6), alignment: .leading, spacing: 5) {
                    ForEach(keys, id: \.self) { key in
                        let on = snapshot.buttons.contains(key)
                        Text(key == .stick ? "摇杆" : key.mappingTitle)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(on ? Color.white : Color.secondary)
                            .frame(width: 38, height: 22)
                            .background(on ? Color.accentColor : Palette.cell, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(Palette.cell)
                    Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1.5)
                    Circle().fill(Color.accentColor)
                        .frame(width: 11, height: 11)
                        .offset(x: snapshot.stick.x * 17, y: -snapshot.stick.y * 17)
                }
                .frame(width: 50, height: 50)
                .help("摇杆位置")
            }
            HStack(alignment: .bottom, spacing: 8) {
                Text("体感").font(.system(size: 10.5)).foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
                HStack(alignment: .bottom, spacing: 2.5) {
                    ForEach(Array(snapshot.motionLevels.enumerated()), id: \.offset) { _, level in
                        Capsule().fill(Color.accentColor.opacity(0.8)).frame(height: max(2.5, level * 16))
                    }
                }
                .frame(height: 16, alignment: .bottom)
            }
        }
    }

    private var checklist: some View {
        SettingsCard {
            HStack {
                Text("使用前检查").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("全部完成后即可使用").font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            // One row when there is room, two rows in a narrow window.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    bluetoothStep
                    accessibilityStep
                    inputMonitoringStep
                    calibrationStep
                }
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow { bluetoothStep; accessibilityStep }
                    GridRow { inputMonitoringStep; calibrationStep }
                }
            }
        }
    }

    private var bluetoothStep: ChecklistStep {
        // A controller asleep to save power is paired, just not connected.
        let asleep = model.status == .sleeping
        let done = model.isConnected || asleep
        return ChecklistStep(
            done: done,
            title: "蓝牙已配对",
            detail: asleep ? "已休眠，按任意键唤醒" : done ? model.deviceName : "未找到 Joy-Con",
            actionTitle: done ? nil : "蓝牙设置",
            action: { model.openBluetoothSettings() }
        )
    }

    private var accessibilityStep: ChecklistStep {
        let done = model.accessibilityTrusted
        return ChecklistStep(
            done: done,
            title: "辅助功能",
            detail: done ? "用于输出鼠标和键盘" : "未授权",
            actionTitle: done ? nil : "授权",
            action: { model.requestAccessibility() }
        )
    }

    private var inputMonitoringStep: ChecklistStep {
        // Only needed when the system blocks reading the controller.
        let done = model.inputMonitoringAccess == .granted || model.isConnected
        return ChecklistStep(
            done: done,
            title: "输入监控",
            detail: done ? "可以读取手柄" : "未授权",
            actionTitle: done ? nil : "授权",
            action: { model.requestInputMonitoring() }
        )
    }

    private var calibrationStep: ChecklistStep {
        let done = (model.calibrationProgress ?? 0) >= 1
        return ChecklistStep(
            done: done,
            title: "校准完成",
            detail: done ? "可以开始使用" : "连接后静置 1 秒",
            actionTitle: nil,
            action: {}
        )
    }
}

private struct ChecklistStep: View {
    let done: Bool
    let title: String
    let detail: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark" : "exclamationmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(done ? Color.green : Color.orange, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).fixedSize()
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .controlSize(.mini)
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 150, maxWidth: .infinity)
        .background(Palette.cell, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
