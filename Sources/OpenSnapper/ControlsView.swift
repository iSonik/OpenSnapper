import Foundation
import SwiftUI

struct ControlsGlassGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            configuration.content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}

struct ControlsView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ControlsImageSection()
                    ControlsToolkitSection()
                }
                .padding(22)
                .padding(.bottom, 10)
            }

            ControlsSettingsButton {
                openWindow(id: "settings-window")
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 26)
        }
        .groupBoxStyle(ControlsGlassGroupBoxStyle())
    }
}
