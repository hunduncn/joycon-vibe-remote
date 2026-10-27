import SwiftUI
import JoyConVibeCore

struct StatusPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @ObservedObject var liveInput: LiveInput

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                hero.frame(width: 520, height: 440)
                VStack(spacing: 18) {
                    calibration.frame(height: 200)
                    live.frame(height: 222)
                }
            }
            checklist
        }
        .onAppear { liveInput.isObserving = true }
        .onDisappear { liveInput.isObserving = false }
    }

    private var hero: some View {
        SettingsCard(padding: 0, fillsHeight: true) {
            HStack(alignment: .top, spacing: 26) {
                JoyConArtwork(highlighted: Set(liveInput.snapshot.buttons.map(JoyConPart.init)))
                    .frame(width: 160, height: 350)
                    .rotationEffect(.degrees(-8))
                    .padding(.leading, 34)
                    .padding(.top, 38)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: model.status.symbolName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(model.status.color)
                            .frame(width: 46, height: 46)
                            .background(model.status.color.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.status.title).font(.system(size: 22, weight: .bold))
                            Text(model.statusDetail).font(.system(size: 12.5)).foregroundStyle(.secondary)
                        }
                    }

                    Text("电量").font(.caption).foregroundStyle(.secondary).padding(.top, 28)
                    HStack(spacing: 10) {
                        ProgressView(value: Double(model.batteryLevel), total: 4)
                            .tint(model.batteryLevel <= 1 ? .orange : .green)
                        Text(model.isConnected && model.batteryLevel > 0 ? "\(model.batteryLevel * 25)%" : "—")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(width: 42, alignment: .trailing)
                    }
                    .padding(.top, 6)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用 Joy-Con 遥控").font(.system(size: 14, weight: .semibold))
                            Text("关闭后按键和体感都不会输出").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("启用 Joy-Con 遥控", isOn: Binding(get: { settings.enabled }, set: { model.setRemoteEnabled($0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(14)
                    .background(Palette.cell, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 24)

                    HStack(spacing: 8) {
                        Button("重新连接") { model.reconnect() }
                        Button("蓝牙设置") { model.openBluetoothSettings() }
                    }
                    .padding(.top, 16)

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }
                }
                .padding(.top, 44)
                .padding(.trailing, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RadialGradient(colors: [Color.accentColor.opacity(0.10), .clear], center: UnitPoint(x: 0.25, y: 0.45), startRadius: 0, endRadius: 300)
            )
        }
    }

    private var calibration: some View {
        let progress = model.calibrationProgress
        return SettingsCard(fillsHeight: true) {
            HStack {
                Text("零点校准").font(.system(size: 14, weight: .semibold))
                Spacer()
                switch progress {
                case nil: StatusPill(text: "未连接", tone: .neutral)
                case let value? where value >= 1: StatusPill(text: "✓ 已完成", tone: .good)
                default: StatusPill(text: "校准中", tone: .warning)
                }
            }
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.10), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress ?? 0)
                        .stroke((progress ?? 0) >= 1 ? Color.green : Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(progress.map { "\(Int($0 * 100))%" } ?? "—")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 10) {
                    Text("连接后把手柄静置约 1 秒即自动完成。光标持续漂移或换了握姿时可以重新校准。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("重新校准") { model.recalibrate() }
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
                Text("实时输入").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("按下手柄上的键会在这里亮起").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 7), count: 5), alignment: .leading, spacing: 7) {
                    ForEach(keys, id: \.self) { key in
                        let on = snapshot.buttons.contains(key)
                        Text(key == .stick ? "摇杆" : key.mappingTitle)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(on ? Color.white : Color.secondary)
                            .frame(width: 48, height: 28)
                            .background(on ? Color.accentColor : Palette.cell, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(Palette.cell)
                        Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1.5)
                        Circle().fill(Color.accentColor)
                            .frame(width: 16, height: 16)
                            .offset(x: snapshot.stick.x * 26, y: -snapshot.stick.y * 26)
                    }
                    .frame(width: 78, height: 78)
                    Text("摇杆").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                Text("体感").font(.caption).foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(snapshot.motionLevels.enumerated()), id: \.offset) { _, level in
                        Capsule().fill(Color.accentColor.opacity(0.8)).frame(height: max(3, level * 22))
                    }
                }
                .frame(height: 22, alignment: .bottom)
            }
        }
    }

    private var checklist: some View {
        SettingsCard {
            HStack {
                Text("使用前检查").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("全部完成后即可使用").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                bluetoothStep
                accessibilityStep
                inputMonitoringStep
                calibrationStep
            }
        }
    }

    private var bluetoothStep: ChecklistStep {
        let done = model.isConnected
        return ChecklistStep(
            done: done,
            title: "蓝牙已配对",
            detail: done ? model.deviceName : "未找到 Joy-Con (R)",
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
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark" : "exclamationmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(done ? Color.green : Color.orange, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Palette.cell, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
