import SwiftUI

private struct RelativeRoundedRectangle: Shape {
    let cornerFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * cornerFraction
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

private struct SuperellipseShape: Shape {
    let exponent: CGFloat

    func path(in rect: CGRect) -> Path {
        let n = max(1.2, exponent)
        let power = 2.0 / n
        let a = rect.width / 2
        let b = rect.height / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let steps = 240

        var path = Path()
        for step in 0...steps {
            let t = (Double(step) / Double(steps)) * (.pi * 2)
            let cosT = CGFloat(cos(t))
            let sinT = CGFloat(sin(t))
            let x = a * signedPower(cosT, power)
            let y = b * signedPower(sinT, power)
            let point = CGPoint(x: center.x + x, y: center.y + y)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func signedPower(_ value: CGFloat, _ power: CGFloat) -> CGFloat {
        let magnitude = CGFloat(pow(Double(abs(value)), Double(power)))
        return value >= 0 ? magnitude : -magnitude
    }
}

struct CanvasClipShape: Shape {
    let isAppIconLayout: Bool
    let appIconShape: EditorState.AppIconShape
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        if !isAppIconLayout {
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        }

        switch appIconShape {
        case .apple:
            return SuperellipseShape(exponent: 5.0).path(in: rect)
        case .classic:
            return RelativeRoundedRectangle(cornerFraction: 0.22).path(in: rect)
        case .round:
            return Circle().path(in: rect)
        case .square:
            return Rectangle().path(in: rect)
        }
    }
}

extension EditorState {
    var canvasClipShape: CanvasClipShape {
        CanvasClipShape(
            isAppIconLayout: isAppIconLayout,
            appIconShape: appIconShape,
            cornerRadius: outerCornerRadius
        )
    }
}
