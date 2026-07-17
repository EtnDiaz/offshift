import SwiftUI

/// A decorative, original Offshift companion. It is drawn in code so the care
/// surface still works without a downloaded brand asset or network access.
struct OffshiftMascotView: View {
    var size: CGFloat = 116
    @State private var dreaming = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(Color(red: 0.07, green: 0.16, blue: 0.35))
                .frame(width: size, height: size * 0.28)
                .offset(y: size * 0.28)

            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .fill(Color(red: 0.16, green: 0.38, blue: 0.82))
                .frame(width: size * 0.86, height: size * 0.34)
                .offset(y: size * 0.16)

            Circle()
                .fill(Color(red: 0.65, green: 0.78, blue: 1.0))
                .frame(width: size * 0.48, height: size * 0.48)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color(red: 0.07, green: 0.16, blue: 0.35))
                        .frame(width: size * 0.28, height: size * 0.035)
                        .offset(y: -size * 0.14)
                }
                .offset(x: -size * 0.1, y: -size * 0.06)

            Triangle()
                .fill(Color(red: 0.18, green: 0.37, blue: 0.84))
                .frame(width: size * 0.4, height: size * 0.36)
                .rotationEffect(.degrees(-16))
                .offset(x: -size * 0.15, y: -size * 0.34)
            Circle()
                .fill(Color(red: 0.51, green: 0.69, blue: 1.0))
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: -size * 0.34, y: -size * 0.48)

            VStack(spacing: -size * 0.03) {
                Text("z").font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                Text("z").font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                Text("z").font(.system(size: size * 0.1, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.39, green: 0.68, blue: 1.0))
            .opacity(dreaming ? 1 : 0.35)
            .offset(x: dreaming ? size * 0.34 : size * 0.24, y: dreaming ? -size * 0.48 : -size * 0.32)
        }
        .frame(width: size * 1.35, height: size * 1.05)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                dreaming = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
