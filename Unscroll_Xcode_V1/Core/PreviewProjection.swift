import Foundation

// Same resizeAspect geometry as AVCaptureVideoPreviewLayer, with y-up Vision joints.
enum PreviewProjection {
    static func point(_ joint: Joint, aspect: Double, width: Double, height: Double, mirrored: Bool) -> (x: Double, y: Double) {
        let ratio = max(0.01, aspect)
        let imageHeight = min(height, width / ratio)
        let imageWidth = imageHeight * ratio
        let normalizedX = joint.x / ratio
        return ((width-imageWidth)/2 + (mirrored ? 1-normalizedX : normalizedX)*imageWidth,
                (height-imageHeight)/2 + (1-joint.y)*imageHeight)
    }
}
