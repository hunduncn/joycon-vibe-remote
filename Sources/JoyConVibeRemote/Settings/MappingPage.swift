import SwiftUI
import JoyConVibeCore

/// Which card sits on which side, ordered top to bottom by where the part is
/// on the controller so leader lines cross as little as possible.
enum MappingLayout {
    static let left: [JoyConPart] = [.plus, .sr, .y, .home, .sl]
    static let right: [JoyConPart] = [.zr, .r, .x, .a, .b, .stick]
    static let fixed: Set<JoyConPart> = [.zr, .sl]
}

struct MappingPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: RemoteSettings
    @ObservedObject var highlight: PressHighlight

    private var highlighted: JoyConPart? {
        guard settings.highlightPressedButton, let button = highlight.button else { return nil }
        return JoyConPart(button)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 0) {
                column(MappingLayout.left, spacing: 22).frame(width: 300)
                Spacer(minLength: 16)
                JoyConArtwork(highlighted: highlighted.map { [$0] } ?? [])
                    .frame(width: 262, height: 568)
                    .anchorPreference(key: MappingAnchorsKey.self, value: .bounds) { MappingAnchors(artwork: $0) }
                Spacer(minLength: 16)
                column(MappingLayout.right, spacing: 10).frame(width: 300)
            }
            .frame(maxHeight: .infinity)
            .overlayPreferenceValue(MappingAnchorsKey.self) { anchors in
                GeometryReader { proxy in
                    LeaderLines(anchors: anchors, proxy: proxy, highlighted: highlighted)
                }
                .allowsHitTesting(false)
            }

            bottomBar
        }
        .onAppear { highlight.isActive = settings.highlightPressedButton }
        .onDisappear { highlight.isActive = false }
        .onChange(of: settings.highlightPressedButton) { _, enabled in highlight.isActive = enabled }
    }

    private func column(_ parts: [JoyConPart], spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(parts, id: \.self) { part in
                MappingCard(part: part, settings: settings, isHighlighted: highlighted == part)
                    .anchorPreference(key: MappingAnchorsKey.self, value: .bounds) { MappingAnchors(cards: [part: $0]) }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("按键定位").font(.system(size: 13, weight: .semibold))
                Text("按下手柄上的键，自动高亮对应的设置卡片").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("按键定位", isOn: $settings.highlightPressedButton)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            Divider().frame(height: 28)
            Text("灰色的「同单按」表示该键在 SL 副层里沿用单按动作")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("恢复默认") { settings.resetButtonMappings() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline))
    }
}

struct MappingAnchors {
    var cards: [JoyConPart: Anchor<CGRect>] = [:]
    var artwork: Anchor<CGRect>?
}

private struct MappingAnchorsKey: PreferenceKey {
    static let defaultValue = MappingAnchors()

    static func reduce(value: inout MappingAnchors, nextValue: () -> MappingAnchors) {
        let next = nextValue()
        value.cards.merge(next.cards) { _, new in new }
        value.artwork = next.artwork ?? value.artwork
    }
}

/// Curves from each part of the drawn controller to the edge of its card.
private struct LeaderLines: View {
    let anchors: MappingAnchors
    let proxy: GeometryProxy
    let highlighted: JoyConPart?

    var body: some View {
        if let artworkAnchor = anchors.artwork {
            let artwork = proxy[artworkAnchor]
            let transform = JoyConGeometry.transform(fitting: artwork.size)
                .concatenating(CGAffineTransform(translationX: artwork.minX, y: artwork.minY))
            Canvas { context, _ in
                for (part, cardAnchor) in anchors.cards where part != highlighted {
                    draw(part, card: proxy[cardAnchor], transform: transform, in: &context, emphasized: false)
                }
                if let highlighted, let cardAnchor = anchors.cards[highlighted] {
                    draw(highlighted, card: proxy[cardAnchor], transform: transform, in: &context, emphasized: true)
                }
            }
        }
    }

    private func draw(
        _ part: JoyConPart,
        card: CGRect,
        transform: CGAffineTransform,
        in context: inout GraphicsContext,
        emphasized: Bool
    ) {
        let center = JoyConGeometry.center(of: part).applying(transform)
        let toLeft = card.midX < center.x
        let end = CGPoint(x: toLeft ? card.maxX : card.minX, y: card.midY)
        let inset = JoyConGeometry.radius(of: part) * transform.a
        let start = CGPoint(x: center.x + (toLeft ? -inset : inset), y: center.y)
        let bend = (end.x - start.x) * 0.5

        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + bend, y: start.y),
            control2: CGPoint(x: end.x - bend, y: end.y)
        )
        let color = emphasized ? Color.accentColor : Color.secondary.opacity(0.45)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: emphasized ? 2 : 1.2, lineCap: .round))

        let dot = Path(ellipseIn: CGRect(x: start.x - 3, y: start.y - 3, width: 6, height: 6))
        context.fill(dot, with: .color(emphasized ? Color.accentColor : Color.secondary.opacity(0.7)))

        if emphasized {
            let direction: CGFloat = toLeft ? 1 : -1
            var arrow = Path()
            arrow.move(to: CGPoint(x: end.x + 7 * direction, y: end.y - 5))
            arrow.addLine(to: end)
            arrow.addLine(to: CGPoint(x: end.x + 7 * direction, y: end.y + 5))
            context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct MappingCard: View {
    let part: JoyConPart
    @ObservedObject var settings: RemoteSettings
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                KeyCap(label: capLabel, systemImage: capSymbol, isHighlighted: isHighlighted)
                Text(name).font(.system(size: 13.5, weight: .semibold))
                Spacer()
                if MappingLayout.fixed.contains(part) {
                    Text("固定")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Palette.cell, in: RoundedRectangle(cornerRadius: 6))
                } else if isHighlighted {
                    Text("刚刚按下")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.06) : Palette.card,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHighlighted ? Color.accentColor.opacity(0.6) : Palette.hairline, lineWidth: isHighlighted ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isHighlighted)
    }

    @ViewBuilder
    private var content: some View {
        switch part {
        case .zr:
            note("按住开启体感鼠标 · ZR + SL 精准体感")
        case .sl:
            note("按住进入副层，各键的「按住 SL」动作生效")
        case .stick:
            VStack(spacing: 6) {
                row("按下") { buttonMenus(for: .stick) }
                row("上下") {
                    ActionMenu(
                        caption: nil,
                        selection: settings.stickVerticalBinding.primary,
                        choices: RemoteStickVerticalAction.primaryChoices,
                        title: \.mappingTitle,
                        isDimmed: { $0 == .none },
                        onSelect: settings.setStickVerticalPrimary
                    )
                    ActionMenu(
                        caption: nil,
                        selection: settings.stickVerticalBinding.withSL,
                        choices: RemoteStickVerticalAction.slChoices,
                        title: \.mappingTitle,
                        isDimmed: { $0 == .usePrimary || $0 == .none },
                        onSelect: settings.setStickVerticalSL
                    )
                }
                note("左右固定为方向键 ← →")
            }
        default:
            HStack(spacing: 8) { buttonMenus(for: part.button) }
        }
    }

    @ViewBuilder
    private func buttonMenus(for button: JoyConButton) -> some View {
        ActionMenu(
            caption: "单按",
            selection: settings.binding(for: button).primary,
            choices: RemoteButtonAction.primaryChoices,
            title: \.mappingTitle,
            isDimmed: { $0 == .none },
            onSelect: { settings.setPrimaryMapping($0, for: button) }
        )
        ActionMenu(
            caption: "按住 SL",
            selection: settings.binding(for: button).withSL,
            choices: RemoteButtonAction.slChoices,
            title: \.mappingTitle,
            isDimmed: { $0 == .usePrimary || $0 == .none },
            onSelect: { settings.setSLMapping($0, for: button) }
        )
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var name: String {
        switch part {
        case .plus: return "加号键"
        case .sr: return "侧键 SR"
        case .sl: return "侧键 SL"
        case .zr: return "扳机 ZR"
        case .r: return "肩键 R"
        case .home: return "Home 键"
        case .stick: return "摇杆"
        case .x, .y, .a, .b: return "\(part.button.mappingTitle) 键"
        }
    }

    private var capLabel: String { part.button.mappingTitle }

    private var capSymbol: String? {
        switch part {
        case .home: return "house.fill"
        case .stick: return "circle.circle"
        default: return nil
        }
    }
}
