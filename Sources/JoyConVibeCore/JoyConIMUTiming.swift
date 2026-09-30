import Foundation

/// A standard Joy-Con input report carries three IMU samples measured at a
/// fixed 200 Hz. Every integration step and filter constant derives from it.
public enum JoyConIMUTiming {
    public static let sampleRate = 200.0
    public static let sampleInterval: TimeInterval = 1.0 / 200.0
}
