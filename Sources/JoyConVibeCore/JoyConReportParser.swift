import Foundation

/// Decodes reports from either Joy-Con. A left controller's buttons come out
/// as the logical button in the mirrored position on the right controller,
/// and its IMU in the right controller's axes, so everything downstream
/// handles both sides the same way.
public struct JoyConReportParser: Sendable {
    public let side: JoyConSide
    public private(set) var gyroCalibration: GyroCalibration
    public private(set) var stickCalibration: StickCalibration

    public init(
        side: JoyConSide = .right,
        gyroCalibration: GyroCalibration = .fallback,
        stickCalibration: StickCalibration = .fallback
    ) {
        self.side = side
        self.gyroCalibration = gyroCalibration
        self.stickCalibration = stickCalibration
    }

    public mutating func decode(reportID: UInt8, bytes: [UInt8]) -> JoyConDecodedReport? {
        let payload = Self.payload(reportID: reportID, bytes: bytes)

        switch reportID {
        case 0x21:
            let reply = parseSPIReply(payload: payload)
            if let reply {
                apply(reply: reply)
            }
            guard let reply else { return nil }
            // 0x21 is a subcommand reply used during initialization. Although
            // its header resembles a standard input report, exposing it as a
            // frame can turn reply bytes into phantom button presses at launch.
            return JoyConDecodedReport(spiReply: reply)
        case 0x30:
            guard let frame = parseStandardFrame(payload: payload) else { return nil }
            return JoyConDecodedReport(frame: frame)
        case 0x3F:
            guard let frame = parseButtonOnlyFrame(payload: payload) else { return nil }
            return JoyConDecodedReport(frame: frame)
        default:
            return nil
        }
    }

    public mutating func apply(reply: SPIFlashReply) {
        switch reply.address {
        case 0x6020:
            if let calibration = Self.parseGyroCalibration(reply.data) {
                gyroCalibration = calibration
            }
        case side.stickCalibrationAddress:
            let parsed = side == .right
                ? Self.parseRightStickCalibration(reply.data)
                : Self.parseLeftStickCalibration(reply.data)
            if let parsed {
                stickCalibration = parsed
            }
        default:
            break
        }
    }

    private static func payload(reportID: UInt8, bytes: [UInt8]) -> ArraySlice<UInt8> {
        // IOHID backends differ on whether the report ID is included in the
        // buffer. Avoid checking only the first byte because the Joy-Con timer
        // can legitimately equal 0x21 or 0x30.
        if reportID == 0x30, bytes.count >= 49, bytes.first == reportID {
            return bytes.dropFirst()
        }
        if reportID == 0x3F, bytes.count >= 12, bytes.first == reportID {
            return bytes.dropFirst()
        }
        if reportID == 0x21,
           bytes.count >= 20,
           bytes.first == reportID,
           bytes[13] & 0x80 != 0,
           bytes[14] == 0x10
        {
            return bytes.dropFirst()
        }
        return bytes[...]
    }

    private func parseStandardFrame(payload: ArraySlice<UInt8>) -> JoyConInputFrame? {
        let data = Array(payload)
        guard data.count >= 11 else { return nil }

        let buttons = side == .right ? Self.parseRightButtons(data) : Self.parseLeftButtons(data)
        let stickOffset = side == .right ? 8 : 5
        let rawStick = Self.decodeStick(data[stickOffset], data[stickOffset + 1], data[stickOffset + 2])
        let stick = normalizedStick(rawStick)

        var gyroSamples: [GyroSample] = []
        if data.count >= 48 {
            for offset in stride(from: 12, through: 36, by: 12) {
                let x = Self.int16(data, offset)
                let y = Self.int16(data, offset + 2)
                let z = Self.int16(data, offset + 4)

                let gx = Self.int16(data, offset + 6)
                let gy = Self.int16(data, offset + 8)
                let gz = Self.int16(data, offset + 10)
                let rate = Vector3(
                    x: (Double(gx) - gyroCalibration.offset.x) * gyroCalibration.coefficient.x,
                    y: (Double(gy) - gyroCalibration.offset.y) * gyroCalibration.coefficient.y,
                    z: (Double(gz) - gyroCalibration.offset.z) * gyroCalibration.coefficient.z
                )
                let acceleration = Vector3(x: Double(x), y: Double(y), z: Double(z))
                gyroSamples.append(
                    side == .right
                        ? GyroSample(degreesPerSecond: rate, acceleration: acceleration)
                        : GyroSample(
                            degreesPerSecond: Self.normalizeLeftAxes(rate),
                            acceleration: Self.normalizeLeftAxes(acceleration)
                        )
                )
            }
        }

        let batteryByte = data[1]
        let batteryLevel: Int
        switch batteryByte & 0xE0 {
        case 0x80: batteryLevel = 4
        case 0x60: batteryLevel = 3
        case 0x40: batteryLevel = 2
        case 0x20: batteryLevel = 1
        default: batteryLevel = 0
        }

        return JoyConInputFrame(
            buttons: buttons,
            stick: stick,
            gyroSamples: gyroSamples,
            batteryLevel: batteryLevel,
            isCharging: batteryByte & 0x10 != 0
        )
    }

    private static func parseRightButtons(_ data: [UInt8]) -> Set<JoyConButton> {
        let rightButtons = data[2]
        let sharedButtons = data[3]
        var buttons = Set<JoyConButton>()
        insert(.y, if: rightButtons & 0x01 != 0, into: &buttons)
        insert(.x, if: rightButtons & 0x02 != 0, into: &buttons)
        insert(.b, if: rightButtons & 0x04 != 0, into: &buttons)
        insert(.a, if: rightButtons & 0x08 != 0, into: &buttons)
        insert(.sr, if: rightButtons & 0x10 != 0, into: &buttons)
        insert(.sl, if: rightButtons & 0x20 != 0, into: &buttons)
        insert(.r, if: rightButtons & 0x40 != 0, into: &buttons)
        insert(.zr, if: rightButtons & 0x80 != 0, into: &buttons)
        insert(.plus, if: sharedButtons & 0x02 != 0, into: &buttons)
        insert(.stick, if: sharedButtons & 0x04 != 0, into: &buttons)
        insert(.home, if: sharedButtons & 0x10 != 0, into: &buttons)
        return buttons
    }

    /// Each left button reports as the right button in the mirrored spot.
    /// The side buttons swap: held upright, the right controller's SL sits
    /// at the bottom of the rail, where the left controller has SR.
    private static func parseLeftButtons(_ data: [UInt8]) -> Set<JoyConButton> {
        let leftButtons = data[4]
        let sharedButtons = data[3]
        var buttons = Set<JoyConButton>()
        insert(.b, if: leftButtons & 0x01 != 0, into: &buttons)
        insert(.x, if: leftButtons & 0x02 != 0, into: &buttons)
        insert(.y, if: leftButtons & 0x04 != 0, into: &buttons)
        insert(.a, if: leftButtons & 0x08 != 0, into: &buttons)
        insert(.sl, if: leftButtons & 0x10 != 0, into: &buttons)
        insert(.sr, if: leftButtons & 0x20 != 0, into: &buttons)
        insert(.r, if: leftButtons & 0x40 != 0, into: &buttons)
        insert(.zr, if: leftButtons & 0x80 != 0, into: &buttons)
        insert(.plus, if: sharedButtons & 0x01 != 0, into: &buttons)
        insert(.stick, if: sharedButtons & 0x08 != 0, into: &buttons)
        insert(.home, if: sharedButtons & 0x20 != 0, into: &buttons)
        return buttons
    }

    /// The left controller's IMU is the right one turned half a turn about
    /// its long axis, so its y and z point the other way.
    private static func normalizeLeftAxes(_ vector: Vector3) -> Vector3 {
        Vector3(x: vector.x, y: -vector.y, z: -vector.z)
    }

    /// Decodes a 0x3F report well enough to notice presses. The trigger,
    /// shoulder, side and system buttons map to their logical buttons; the
    /// four face buttons only need to be distinct from each other.
    private func parseButtonOnlyFrame(payload: ArraySlice<UInt8>) -> JoyConInputFrame? {
        let data = Array(payload)
        guard data.count >= 3 else { return nil }
        let face = data[0]
        let system = data[1]
        var buttons = Set<JoyConButton>()
        Self.insert(.b, if: face & 0x01 != 0, into: &buttons)
        Self.insert(.y, if: face & 0x02 != 0, into: &buttons)
        Self.insert(.a, if: face & 0x04 != 0, into: &buttons)
        Self.insert(.x, if: face & 0x08 != 0, into: &buttons)
        // Physical SL and SR, swapped on the left controller as in 0x30.
        Self.insert(side == .right ? .sl : .sr, if: face & 0x10 != 0, into: &buttons)
        Self.insert(side == .right ? .sr : .sl, if: face & 0x20 != 0, into: &buttons)
        let plus: UInt8 = side == .right ? 0x02 : 0x01
        let stick: UInt8 = side == .right ? 0x08 : 0x04
        let home: UInt8 = side == .right ? 0x10 : 0x20
        Self.insert(.plus, if: system & plus != 0, into: &buttons)
        Self.insert(.stick, if: system & stick != 0, into: &buttons)
        Self.insert(.home, if: system & home != 0, into: &buttons)
        Self.insert(.r, if: system & 0x40 != 0, into: &buttons)
        Self.insert(.zr, if: system & 0x80 != 0, into: &buttons)
        return JoyConInputFrame(buttons: buttons, stick: .zero, isButtonOnly: true)
    }

    private func parseSPIReply(payload: ArraySlice<UInt8>) -> SPIFlashReply? {
        let data = Array(payload)
        guard data.count >= 19 else { return nil }
        let acknowledged = data[12] & 0x80 != 0
        guard acknowledged, data[13] == 0x10 else { return nil }

        let address = UInt32(data[14])
            | (UInt32(data[15]) << 8)
            | (UInt32(data[16]) << 16)
            | (UInt32(data[17]) << 24)
        let length = Int(data[18])
        guard data.count >= 19 + length else { return nil }
        return SPIFlashReply(address: address, data: Array(data[19..<(19 + length)]))
    }

    private func normalizedStick(_ raw: (x: UInt16, y: UInt16)) -> StickPosition {
        let deltaX = Double(raw.x) - stickCalibration.centerX
        let deltaY = Double(raw.y) - stickCalibration.centerY
        let xRange = deltaX < 0 ? stickCalibration.negativeRangeX : stickCalibration.positiveRangeX
        let yRange = deltaY < 0 ? stickCalibration.negativeRangeY : stickCalibration.positiveRangeY
        let x = max(-1, min(1, deltaX / xRange))
        let y = max(-1, min(1, deltaY / yRange))
        return StickPosition(x: x, y: y)
    }

    private static func insert(
        _ button: JoyConButton,
        if condition: Bool,
        into buttons: inout Set<JoyConButton>
    ) {
        if condition { buttons.insert(button) }
    }

    private static func decodeStick(_ first: UInt8, _ second: UInt8, _ third: UInt8) -> (x: UInt16, y: UInt16) {
        let x = UInt16(first) | ((UInt16(second) & 0x0F) << 8)
        let y = (UInt16(second) >> 4) | (UInt16(third) << 4)
        return (x, y)
    }

    private static func parseGyroCalibration(_ data: [UInt8]) -> GyroCalibration? {
        guard data.count >= 24 else { return nil }
        let offset = Vector3(
            x: Double(int16(data, 12)),
            y: Double(int16(data, 14)),
            z: Double(int16(data, 16))
        )
        let sensitivity = Vector3(
            x: Double(int16(data, 18)),
            y: Double(int16(data, 20)),
            z: Double(int16(data, 22))
        )
        let denominatorX = sensitivity.x - offset.x
        let denominatorY = sensitivity.y - offset.y
        let denominatorZ = sensitivity.z - offset.z
        guard abs(denominatorX) > 1, abs(denominatorY) > 1, abs(denominatorZ) > 1 else { return nil }

        return GyroCalibration(
            offset: offset,
            coefficient: Vector3(
                x: 936 / denominatorX,
                y: 936 / denominatorY,
                z: 936 / denominatorZ
            )
        )
    }

    private static func parseRightStickCalibration(_ data: [UInt8]) -> StickCalibration? {
        guard data.count >= 9 else { return nil }
        let value0 = UInt16(data[0]) | ((UInt16(data[1]) & 0x0F) << 8)
        let value1 = (UInt16(data[1]) >> 4) | (UInt16(data[2]) << 4)
        let value2 = UInt16(data[3]) | ((UInt16(data[4]) & 0x0F) << 8)
        let value3 = (UInt16(data[4]) >> 4) | (UInt16(data[5]) << 4)
        let value4 = UInt16(data[6]) | ((UInt16(data[7]) & 0x0F) << 8)
        let value5 = (UInt16(data[7]) >> 4) | (UInt16(data[8]) << 4)

        return StickCalibration(
            centerX: Double(value0),
            centerY: Double(value1),
            negativeRangeX: Double(value2),
            positiveRangeX: Double(value4),
            negativeRangeY: Double(value3),
            positiveRangeY: Double(value5)
        )
    }

    /// The left stick stores the same six values as the right one, in the
    /// order: above center, center, below center.
    private static func parseLeftStickCalibration(_ data: [UInt8]) -> StickCalibration? {
        guard data.count >= 9 else { return nil }
        let value0 = UInt16(data[0]) | ((UInt16(data[1]) & 0x0F) << 8)
        let value1 = (UInt16(data[1]) >> 4) | (UInt16(data[2]) << 4)
        let value2 = UInt16(data[3]) | ((UInt16(data[4]) & 0x0F) << 8)
        let value3 = (UInt16(data[4]) >> 4) | (UInt16(data[5]) << 4)
        let value4 = UInt16(data[6]) | ((UInt16(data[7]) & 0x0F) << 8)
        let value5 = (UInt16(data[7]) >> 4) | (UInt16(data[8]) << 4)

        return StickCalibration(
            centerX: Double(value2),
            centerY: Double(value3),
            negativeRangeX: Double(value4),
            positiveRangeX: Double(value0),
            negativeRangeY: Double(value5),
            positiveRangeY: Double(value1)
        )
    }

    private static func int16(_ data: [UInt8], _ offset: Int) -> Int16 {
        let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        return Int16(bitPattern: raw)
    }
}
