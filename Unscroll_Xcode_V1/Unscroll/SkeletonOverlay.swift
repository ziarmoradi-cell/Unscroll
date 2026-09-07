import SwiftUI

struct SkeletonOverlay: View {
    let frame: PoseFrame?
    let valid: Bool
    let mirrored: Bool
    var body: some View {
        Canvas { context, size in
            guard let frame, frame.people == 1 else { return }
            let color: Color = valid ? .green : .orange
            func visible(_ j: Joint) -> Bool { j.confidence >= 0.1 && j.x.isFinite && j.y.isFinite }
            func point(_ j: Joint) -> CGPoint {
                let p = PreviewProjection.point(j, aspect: frame.aspectRatio, width: size.width, height: size.height, mirrored: mirrored)
                return CGPoint(x: p.x, y: p.y)
            }
            func line(_ a: Joint, _ b: Joint) {
                guard visible(a), visible(b) else { return }
                var path = Path(); path.move(to: point(a)); path.addLine(to: point(b))
                context.stroke(path, with: .color(.black.opacity(0.65)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
            for body in [frame.left, frame.right].compactMap({ $0 }) {
                line(body.shoulder, body.elbow); line(body.elbow, body.wrist)
                line(body.shoulder, body.hip); line(body.hip, body.knee); line(body.knee, body.ankle)
                for joint in [body.shoulder, body.elbow, body.wrist, body.hip, body.knee, body.ankle] where visible(joint) {
                    let p = point(joint)
                    let circle = Path(ellipseIn: CGRect(x: p.x-5, y: p.y-5, width: 10, height: 10))
                    context.fill(circle, with: .color(.white)); context.stroke(circle, with: .color(color), lineWidth: 2)
                }
            }
            if let l = frame.left, let r = frame.right { line(l.shoulder, r.shoulder); line(l.hip, r.hip) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
