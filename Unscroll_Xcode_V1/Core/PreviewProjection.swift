import Foundation

// Same resizeAspect geometry as AVCaptureVideoPreviewLayer, with y-up Vision joints.
enum PreviewProjection {
    // EXIF 6/8 rotate analysis clockwise/counterclockwise. Undo before aspect scaling.
    static func originalJoint(u: Double, v: Double, orientation: UInt32, aspect: Double, confidence: Double) -> Joint {
        switch orientation {
        case 6: return Joint(x: (1-v)*aspect, y: u, confidence: confidence)
        case 8: return Joint(x: v*aspect, y: 1-u, confidence: confidence)
        default: return Joint(x: u*aspect, y: v, confidence: confidence)
        }
    }
    static func point(_ joint: Joint, aspect: Double, width: Double, height: Double, mirrored: Bool) -> (x: Double, y: Double) {
        let ratio = max(0.01, aspect)
        let imageHeight = min(height, width / ratio)
        let imageWidth = imageHeight * ratio
        let normalizedX = joint.x / ratio
        return ((width-imageWidth)/2 + (mirrored ? 1-normalizedX : normalizedX)*imageWidth,
                (height-imageHeight)/2 + (1-joint.y)*imageHeight)
    }
}
