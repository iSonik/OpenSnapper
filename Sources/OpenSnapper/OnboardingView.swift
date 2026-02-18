import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var editor: EditorState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.11, blue: 0.20), Color(red: 0.09, green: 0.18, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Welcome to OpenSnapper")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text("To capture screenshots, macOS requires Screen Recording permission.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Click Request Permission to trigger the macOS popup.")
                    Text("2. If denied, open System Settings and enable Screen Recording.")
                    Text("3. Return here and click I've Enabled It.")
                }
                .font(.body)
                .foregroundStyle(.white.opacity(0.84))

                HStack(spacing: 10) {
                    Button("Request Permission") {
                        editor.requestScreenCaptureAndOpenSettingsIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open System Settings") {
                        editor.openScreenRecordingSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("I've Enabled It") {
                        editor.confirmPermissionFromOnboarding()
                    }
                    .buttonStyle(.bordered)
                }

                Text(editor.onboardingMessage)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(36)
            .frame(maxWidth: 780)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
    }
}
