import SwiftUI
import JoyConVibeCore

/// Every part of the drawn controller that a setting can point at.
enum JoyConPart: Hashable, CaseIterable {
    case zr, r, sr, sl, plus, x, y, a, b, stick, home

    var button: JoyConButton {
        switch self {
        case .zr: return .zr
        case .r: return .r
        case .sr: return .sr
        case .sl: return .sl
        case .plus: return .plus
        case .x: return .x
        case .y: return .y
        case .a: return .a
        case .b: return .b
        case .stick: return .stick
        case .home: return .home
        }
    }

    init(_ button: JoyConButton) {
        switch button {
        case .zr: self = .zr
        case .r: self = .r
        case .sr: self = .sr
        case .sl: self = .sl
        case .plus: self = .plus
        case .x: self = .x
        case .y: self = .y
        case .a: self = .a
        case .b: self = .b
        case .stick: self = .stick
        case .home: self = .home
        }
    }
}

/// Geometry of a right Joy-Con seen from the front, in a fixed design space.
/// The artwork and the leader lines both read positions from here, so a line
/// always lands on the part it describes. The left Joy-Con is its mirror
/// image, except that its stick sits above the buttons instead of below.
enum JoyConGeometry {
    static let size = CGSize(width: 240, height: 520)

    static let body = CGRect(x: 46, y: 46, width: 168, height: 440)
    static let topRightRadius: CGFloat = 92
    static let bottomRightRadius: CGFloat = 78
    static let leftRadius: CGFloat = 12
    static let rail = CGRect(x: 28, y: 58, width: 20, height: 416)
    static let srButton = CGRect(x: 18, y: 104, width: 16, height: 82)
    static let slButton = CGRect(x: 18, y: 374, width: 16, height: 82)

    /// The shoulder buttons run along the top edge and wrap the rounded
    /// top-right corner: R hugs the shell, ZR peeks out behind it.
    static let shoulderCenter = CGPoint(
        x: body.maxX - topRightRadius,
        y: body.minY + topRightRadius
    )
    static let rBand: ClosedRange<CGFloat> = 95...106
    static let rStartX: CGFloat = 98
    static let rEnd = Angle.degrees(-10)
    static let zrBand: ClosedRange<CGFloat> = 108...121
    static let zrStartX: CGFloat = 116
    static let zrEnd = Angle.degrees(-38)

    static let plus = CGPoint(x: 84, y: 88)
    static let faceCenter = CGPoint(x: 152, y: 160)
    static let faceSpacing: CGFloat = 31
    static let faceRadius: CGFloat = 15.5
    static let stick = CGPoint(x: 140, y: 276)
    static let stickRadius: CGFloat = 35
    static let home = CGPoint(x: 100, y: 360)
    static let homeRadius: CGFloat = 13

    static func center(of part: JoyConPart, side: JoyConSide) -> CGPoint {
        guard side == .left else { return center(of: part) }
        switch part {
        case .stick:
            return mirrored(faceCenter)
        case .x, .y, .a, .b:
            // The buttons keep their mirrored arrangement around the spot
            // where the right controller has its stick.
            let offset = mirrored(center(of: part)).x - mirrored(faceCenter).x
            let rise = center(of: part).y - faceCenter.y
            let dpad = mirrored(stick)
            return CGPoint(x: dpad.x + offset, y: dpad.y + rise)
        default:
            return mirrored(center(of: part))
        }
    }

    static func labelPoint(of part: JoyConPart, side: JoyConSide) -> CGPoint {
        switch part {
        case .zr, .r: return side == .left ? mirrored(labelPoint(of: part)) : labelPoint(of: part)
        default: return center(of: part, side: side)
        }
    }

    static func radius(of part: JoyConPart, side: JoyConSide) -> CGFloat {
        guard side == .left else { return radius(of: part) }
        switch part {
        case .stick: return stickRadius
        case .x, .y, .a, .b: return faceRadius
        default: return radius(of: part)
        }
    }

    static func mirrored(_ point: CGPoint) -> CGPoint {
        CGPoint(x: size.width - point.x, y: point.y)
    }

    static func center(of part: JoyConPart) -> CGPoint {
        switch part {
        case .zr: return onShoulder(radius: zrBand.mid, angle: .degrees(-46))
        case .r: return onShoulder(radius: rBand.mid, angle: .degrees(-18))
        case .sr: return CGPoint(x: srButton.midX, y: srButton.midY)
        case .sl: return CGPoint(x: slButton.midX, y: slButton.midY)
        case .plus: return plus
        case .x: return CGPoint(x: faceCenter.x, y: faceCenter.y - faceSpacing)
        case .y: return CGPoint(x: faceCenter.x - faceSpacing, y: faceCenter.y)
        case .a: return CGPoint(x: faceCenter.x + faceSpacing, y: faceCenter.y)
        case .b: return CGPoint(x: faceCenter.x, y: faceCenter.y + faceSpacing)
        case .stick: return stick
        case .home: return home
        }
    }

    /// Where the shoulder buttons print their names, clear of the point a
    /// leader line starts from.
    static func labelPoint(of part: JoyConPart) -> CGPoint {
        switch part {
        case .zr: return onShoulder(radius: zrBand.mid, angle: .degrees(-68))
        case .r: return onShoulder(radius: rBand.mid, angle: .degrees(-42))
        default: return center(of: part)
        }
    }

    /// How far a leader line should stay away from the part's center, so it
    /// starts at the edge instead of covering the label.
    static func radius(of part: JoyConPart) -> CGFloat {
        switch part {
        case .x, .y, .a, .b: return faceRadius
        case .stick: return stickRadius
        case .home: return homeRadius
        case .plus: return 12
        case .sr, .sl: return 0
        case .r, .zr: return 0
        }
    }

    static func onShoulder(radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: shoulderCenter.x + radius * CGFloat(cos(angle.radians)),
            y: shoulderCenter.y + radius * CGFloat(sin(angle.radians))
        )
    }

    /// Maps design-space points into a view of `size`, fitted and centered.
    static func transform(fitting viewSize: CGSize) -> CGAffineTransform {
        let scale = min(viewSize.width / size.width, viewSize.height / size.height)
        let x = (viewSize.width - size.width * scale) / 2
        let y = (viewSize.height - size.height * scale) / 2
        return CGAffineTransform(translationX: x, y: y).scaledBy(x: scale, y: scale)
    }
}

private extension ClosedRange where Bound == CGFloat {
    var mid: CGFloat { (lowerBound + upperBound) / 2 }
}

struct JoyConArtwork: View {
    var side: JoyConSide = .right
    var highlighted: Set<JoyConPart> = []
    var showsLabels = true

    // Line-art style: pink outlines on a pale pink shell with white keys.
    static let ink = Color(red: 0.88, green: 0.32, blue: 0.56)
    private static let shell = Color(red: 0.99, green: 0.93, blue: 0.95)
    private static let key = Color.white
    private static let soft = Color(red: 0.96, green: 0.70, blue: 0.80)
    private static let accent = Color.accentColor

    var body: some View {
        Canvas { context, size in
            context.concatenate(JoyConGeometry.transform(fitting: size))
            // The shell, rail and shoulders are drawn as the right controller
            // and flipped for the left one; buttons and text are placed
            // unflipped so glyphs read the right way round.
            var shellLayer = context
            if side == .left {
                shellLayer.concatenate(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: JoyConGeometry.size.width, ty: 0))
            }
            let line = StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
            let fine = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

            func isOn(_ part: JoyConPart) -> Bool { highlighted.contains(part) }
            func fill(_ part: JoyConPart, _ base: Color) -> Color { isOn(part) ? Self.accent : base }
            func stroke(_ part: JoyConPart) -> Color { isOn(part) ? Self.accent : Self.ink }
            func outlined(_ path: Path, _ part: JoyConPart, base: Color = Self.key, style: StrokeStyle = line) {
                context.fill(path, with: .color(fill(part, base)))
                context.stroke(path, with: .color(stroke(part)), style: style)
            }
            func outlinedBody(_ path: Path, _ part: JoyConPart, base: Color = Self.key, style: StrokeStyle = line) {
                shellLayer.fill(path, with: .color(fill(part, base)))
                shellLayer.stroke(path, with: .color(stroke(part)), style: style)
            }

            // Shoulder buttons sit behind the shell: ZR solid, R a softer band.
            outlinedBody(Self.band(radii: JoyConGeometry.zrBand, startX: JoyConGeometry.zrStartX, end: JoyConGeometry.zrEnd), .zr, base: Self.ink)
            outlinedBody(Self.band(radii: JoyConGeometry.rBand, startX: JoyConGeometry.rStartX, end: JoyConGeometry.rEnd), .r, base: Self.soft)

            let rail = Path(roundedRect: JoyConGeometry.rail, cornerRadius: 8)
            shellLayer.fill(rail, with: .color(Self.shell))
            shellLayer.stroke(rail, with: .color(Self.ink), style: line)
            for (part, rect) in [(JoyConPart.sr, JoyConGeometry.srButton), (.sl, JoyConGeometry.slButton)] {
                outlinedBody(Path(roundedRect: rect, cornerRadius: 7), part)
            }

            let shellPath = Self.shellPath()
            shellLayer.fill(shellPath, with: .color(Self.shell))
            shellLayer.stroke(shellPath, with: .color(Self.ink), style: line)
            // The seam where the shell meets the rail.
            var seam = Path()
            seam.move(to: CGPoint(x: JoyConGeometry.body.minX + 8, y: JoyConGeometry.body.minY + 14))
            seam.addLine(to: CGPoint(x: JoyConGeometry.body.minX + 8, y: JoyConGeometry.body.maxY - 14))
            shellLayer.stroke(seam, with: .color(Self.ink.opacity(0.7)), style: fine)

            // Plus (or minus) button: a ring with the sign inside.
            let plusCenter = JoyConGeometry.center(of: .plus, side: side)
            outlined(Self.circle(plusCenter, 12), .plus, style: fine)
            var plus = Path()
            plus.move(to: CGPoint(x: plusCenter.x - 6, y: plusCenter.y))
            plus.addLine(to: CGPoint(x: plusCenter.x + 6, y: plusCenter.y))
            if side == .right {
                plus.move(to: CGPoint(x: plusCenter.x, y: plusCenter.y - 6))
                plus.addLine(to: CGPoint(x: plusCenter.x, y: plusCenter.y + 6))
            }
            context.stroke(plus, with: .color(isOn(.plus) ? .white : Self.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Face buttons.
            for part in [JoyConPart.x, .y, .a, .b] {
                let letter = side.keyLabel(part.button)
                let center = JoyConGeometry.center(of: part, side: side)
                outlined(Self.circle(center, JoyConGeometry.faceRadius), part)
                context.draw(
                    Text(letter)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isOn(part) ? .white : Self.ink),
                    at: center
                )
            }

            // Stick: base ring and cap ring.
            let stick = JoyConGeometry.center(of: .stick, side: side)
            outlined(Self.circle(stick, JoyConGeometry.stickRadius), .stick)
            context.stroke(Self.circle(stick, 24), with: .color(isOn(.stick) ? .white : Self.ink), style: line)

            // Home button with its house glyph, or the left capture button:
            // a rounded square with a dot.
            let home = JoyConGeometry.center(of: .home, side: side)
            if side == .left {
                let square = CGRect(x: home.x - 11, y: home.y - 11, width: 22, height: 22)
                outlined(Path(roundedRect: square, cornerRadius: 5), .home, style: fine)
                context.stroke(Self.circle(home, 5), with: .color(isOn(.home) ? .white : Self.ink), style: StrokeStyle(lineWidth: 2))
            } else {
            outlined(Self.circle(home, JoyConGeometry.homeRadius), .home, style: fine)
            var house = Path()
            house.move(to: CGPoint(x: home.x - 5.5, y: home.y + 0.5))
            house.addLine(to: CGPoint(x: home.x, y: home.y - 5))
            house.addLine(to: CGPoint(x: home.x + 5.5, y: home.y + 0.5))
            house.addLine(to: CGPoint(x: home.x + 5.5, y: home.y + 5))
            house.addLine(to: CGPoint(x: home.x - 5.5, y: home.y + 5))
            house.closeSubpath()
            context.stroke(house, with: .color(isOn(.home) ? .white : Self.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }

            if showsLabels {
                let labelFont = Font.system(size: 9, weight: .heavy, design: .rounded)
                context.draw(Text(side.keyLabel(.zr)).font(labelFont).foregroundColor(.white), at: JoyConGeometry.labelPoint(of: .zr, side: side))
                context.draw(
                    Text(side.keyLabel(.r)).font(labelFont).foregroundColor(.white),
                    at: JoyConGeometry.labelPoint(of: .r, side: side)
                )
            }
        }
        .aspectRatio(JoyConGeometry.size, contentMode: .fit)
        .accessibilityLabel(side == .right ? "右手 Joy-Con 示意图" : "左手 Joy-Con 示意图")
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// A band that runs straight along the top edge from `startX`, then
    /// follows the rounded corner down to `end`, with rounded ends.
    private static func band(radii: ClosedRange<CGFloat>, startX: CGFloat, end: Angle) -> Path {
        let center = JoyConGeometry.shoulderCenter
        let capRadius = (radii.upperBound - radii.lowerBound) / 2
        let mid = (radii.upperBound + radii.lowerBound) / 2
        var path = Path()
        path.move(to: CGPoint(x: startX, y: center.y - radii.upperBound))
        path.addLine(to: CGPoint(x: center.x, y: center.y - radii.upperBound))
        path.addArc(center: center, radius: radii.upperBound, startAngle: .degrees(-90), endAngle: end, clockwise: false)
        path.addArc(center: JoyConGeometry.onShoulder(radius: mid, angle: end), radius: capRadius, startAngle: end, endAngle: end + .degrees(180), clockwise: false)
        path.addArc(center: center, radius: radii.lowerBound, startAngle: end, endAngle: .degrees(-90), clockwise: true)
        path.addLine(to: CGPoint(x: startX, y: center.y - radii.lowerBound))
        path.addArc(center: CGPoint(x: startX, y: center.y - mid), radius: capRadius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }

    private static func shellPath(inset: CGFloat = 0) -> Path {
        let r = JoyConGeometry.body.insetBy(dx: inset, dy: inset)
        let tr = JoyConGeometry.topRightRadius - inset
        let br = JoyConGeometry.bottomRightRadius - inset
        let lr = max(JoyConGeometry.leftRadius - inset, 2)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + lr, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        path.addArc(center: CGPoint(x: r.maxX - tr, y: r.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        path.addArc(center: CGPoint(x: r.maxX - br, y: r.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX + lr, y: r.maxY))
        path.addArc(center: CGPoint(x: r.minX + lr, y: r.maxY - lr), radius: lr, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + lr))
        path.addArc(center: CGPoint(x: r.minX + lr, y: r.minY + lr), radius: lr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// A small solid Joy-Con, sized like an SF Symbol, for status badges: the
/// shell with the stick and buttons cut out. The left one is the mirror
/// image with its stick above the buttons.
struct JoyConGlyph: View {
    let side: JoyConSide

    private static let size = CGSize(width: 12, height: 22)

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width / Self.size.width, canvasSize.height / Self.size.height)
            context.translateBy(
                x: (canvasSize.width - Self.size.width * scale) / 2,
                y: (canvasSize.height - Self.size.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            if side == .left {
                context.concatenate(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: Self.size.width, ty: 0))
            }
            var path = Self.shell()
            // Right controller: buttons on top, stick below. Left: swapped.
            let buttons = CGPoint(x: 6.6, y: side == .right ? 6.2 : 13)
            let stick = CGPoint(x: 6.2, y: side == .right ? 13 : 6.2)
            path.addEllipse(in: CGRect(x: stick.x - 2.6, y: stick.y - 2.6, width: 5.2, height: 5.2))
            for (dx, dy) in [(0.0, -2.0), (2.0, 0.0), (0.0, 2.0), (-2.0, 0.0)] {
                path.addEllipse(in: CGRect(x: buttons.x + dx - 0.85, y: buttons.y + dy - 0.85, width: 1.7, height: 1.7))
            }
            context.fill(path, with: .foreground, style: FillStyle(eoFill: true))
        }
        .aspectRatio(Self.size, contentMode: .fit)
    }

    private static func shell() -> Path {
        let rect = CGRect(origin: .zero, size: size)
        let top: CGFloat = 6
        let bottom: CGFloat = 5
        let inner: CGFloat = 1.5
        var path = Path()
        path.move(to: CGPoint(x: inner, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: 0))
        path.addArc(center: CGPoint(x: rect.maxX - top, y: top), radius: top, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addArc(center: CGPoint(x: rect.maxX - bottom, y: rect.maxY - bottom), radius: bottom, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: inner, y: rect.maxY))
        path.addArc(center: CGPoint(x: inner, y: rect.maxY - inner), radius: inner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: inner))
        path.addArc(center: CGPoint(x: inner, y: inner), radius: inner, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
