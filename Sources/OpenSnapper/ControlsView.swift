import Foundation
import SwiftUI

struct ControlsView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ControlsImageSection()
                ControlsToolkitSection()
                ControlsBackgroundSection()
                ControlsLayoutSection()

                Spacer(minLength: 0)

                ControlsSettingsButton {
                    openWindow(id: "settings-window")
                }
                .padding(.bottom, 26)
            }
            .padding(22)
        }
    }
}
