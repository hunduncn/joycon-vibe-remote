import SwiftUI
import JoyConVibeCore

struct MotionPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings

    private let standard = PointerSettings()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            direction.frame(minWidth: 270, maxWidth: 310)
            feel
        }
        .frame(maxHeight: 460, alignment: .top)
        // Rebuild controls that hold their own copy of a value after a reset.
        .id(settings.pointerTuningRevision)
    }

    private var direction: some View {
        SettingsCard(title: "方向", fillsHeight: true) {
            ScreenSketch()
                .frame(height: 112)

            ZStack {
                JoyConArtwork(showsLabels: false)
                    .frame(width: 66, height: 144)
                    .rotationEffect(.degrees(-14))
                CurvedArrow(clockwise: false)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 72)
                    .offset(x: -72, y: -6)
                CurvedArrow(clockwise: true)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 72)
                    .offset(x: 72, y: -6)
                VStack(alignment: .leading, spacing: 1) {
                    Text("左右转动手腕").font(.system(size: 11.5, weight: .semibold))
                    Text("光标左右移动").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: 56)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("上下抬腕").font(.system(size: 11.5, weight: .semibold))
                    Text("光标上下移动").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: 56)
            }
            .frame(height: 176)

            Spacer(minLength: 0)
            HStack(spacing: 8) {
                InvertToggle(title: "水平反向", initialValue: settings.invertHorizontal) { settings.invertHorizontal = $0 }
                InvertToggle(title: "垂直反向", initialValue: settings.invertVertical) { settings.invertVertical = $0 }
            }
        }
    }

    private var feel: some View {
        SettingsCard(fillsHeight: true) {
            HStack {
                Text("手感").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("恢复默认") { model.resetPointerTuning() }
                    .controlSize(.small)
            }
            VStack(spacing: 10) {
                TuningSlider(
                    title: "整体灵敏度", detail: "手腕转同样角度，光标走多远",
                    initialValue: settings.sensitivity, range: 0.25...4, step: 0.05,
                    defaultValue: standard.sensitivity,
                    onValueChanged: { settings.sensitivity = $0 },
                    onEditingChanged: model.setPointerTuningEditing
                )
                TuningSlider(
                    title: "水平倍率", detail: "左右比上下更快，适合宽屏",
                    initialValue: settings.horizontalSensitivityMultiplier, range: 0.75...2.5, step: 0.05,
                    defaultValue: standard.horizontalSensitivityMultiplier,
                    onValueChanged: { settings.horizontalSensitivityMultiplier = $0 },
                    onEditingChanged: model.setPointerTuningEditing
                )
                TuningSlider(
                    title: "加速度", detail: "快速甩动时额外加速",
                    initialValue: settings.accelerationStrength, range: 0...2, step: 0.05,
                    defaultValue: standard.accelerationStrength, lowerLabel: "关",
                    onValueChanged: { settings.accelerationStrength = $0 },
                    onEditingChanged: model.setPointerTuningEditing
                )
                TuningSlider(
                    title: "稳定度", detail: "越高越能压住手抖，但微调更钝",
                    initialValue: settings.stabilizationStrength, range: 0...2, step: 0.05,
                    defaultValue: standard.stabilizationStrength,
                    onValueChanged: { settings.stabilizationStrength = $0 },
                    onEditingChanged: model.setPointerTuningEditing
                )
                TuningSlider(
                    title: "精准比例", detail: "按住 ZR + SL 时的速度",
                    initialValue: settings.precisionMultiplier, range: 0.1...0.6, step: 0.05,
                    defaultValue: standard.precisionMultiplier,
                    format: { "\(Int(($0 * 100).rounded()))%" },
                    onValueChanged: { settings.precisionMultiplier = $0 },
                    onEditingChanged: model.setPointerTuningEditing
                )
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image(systemName: "lightbulb").font(.system(size: 11)).foregroundStyle(.yellow)
                Text("小竖线是默认值，一次只改一项更容易找到手感。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Button("重新校准") { model.recalibrate() }
                    .controlSize(.small)
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.accentColor.opacity(0.2)))
        }
    }
}

private struct InvertToggle: View {
    let title: String
    let onChange: (Bool) -> Void
    @State private var isOn: Bool

    init(title: String, initialValue: Bool, onChange: @escaping (Bool) -> Void) {
        self.title = title
        self.onChange = onChange
        _isOn = State(initialValue: initialValue)
    }

    var body: some View {
        Toggle(title, isOn: Binding(get: { isOn }, set: { isOn = $0; onChange($0) }))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 11.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Palette.cell, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A dark screen with the pointer travelling along a dashed arc.
private struct ScreenSketch: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(red: 0.12, green: 0.14, blue: 0.15))
            Capsule().fill(Color.white.opacity(0.12)).frame(height: 6).padding(9)
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                Path { path in
                    path.move(to: CGPoint(x: w * 0.18, y: h * 0.78))
                    path.addCurve(
                        to: CGPoint(x: w * 0.78, y: h * 0.58),
                        control1: CGPoint(x: w * 0.36, y: h * 0.30),
                        control2: CGPoint(x: w * 0.62, y: h * 0.30)
                    )
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 7]))
                Image(systemName: "cursorarrow")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .position(x: w * 0.78 + 5, y: h * 0.58 + 8)
            }
            Text("屏幕").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)).padding(9).frame(maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

/// A curved arrow from bottom to top, bending away from the controller.
private struct CurvedArrow: Shape {
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: clockwise ? rect.minX : rect.maxX, y: clockwise ? rect.minY : rect.maxY)
        let end = CGPoint(x: clockwise ? rect.minX + 4 : rect.maxX - 4, y: clockwise ? rect.maxY : rect.minY)
        let bulge = CGPoint(x: clockwise ? rect.maxX : rect.minX, y: rect.midY)
        path.move(to: start)
        path.addQuadCurve(to: end, control: bulge)
        let direction: CGFloat = clockwise ? 1 : -1
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - 11 * direction + (clockwise ? 3 : -3), y: end.y - 4 * direction))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x + 3 * direction, y: end.y - 12 * direction))
        return path
    }
}
