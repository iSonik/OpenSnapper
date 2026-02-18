import AppKit
import CoreGraphics
import Foundation
import SwiftUI

extension EditorState {
    enum AnnotationTool: String, CaseIterable, Identifiable {
        case none
        case box
        case arrow

        var id: String { rawValue }
    }

    struct Annotation: Identifiable, Equatable {
        enum Kind: Equatable {
            case box
            case arrow
        }

        let id: UUID
        let kind: Kind
        let start: CGPoint
        let end: CGPoint
    }

    struct SensitiveRegion: Identifiable, Equatable {
        let id: UUID
        let imageNormalizedRect: CGRect
    }

    struct Snapshot {
        let sourceImage: NSImage?
        let centeringEnabled: Bool
        let detectedSubjectCenterX: CGFloat?
        let detectedSubjectCenterY: CGFloat?
        let centeringSource: CenteringSource?
        let isAppIconLayout: Bool
        let appIconShape: AppIconShape
        let backgroundStyle: BackgroundStyle
        let solidColor: Color
        let canvasPadding: CGFloat
        let outerCornerRadius: CGFloat
        let imageCornerRadius: CGFloat
        let shadowRadius: CGFloat
        let shadowOpacity: Double
        let imageScale: CGFloat
        let imageOffsetX: CGFloat
        let imageOffsetY: CGFloat
        let aspectRatio: CGFloat
        let annotations: [Annotation]
        let redactionRegions: [SensitiveRegion]
    }

    struct RecentScreenshot: Identifiable {
        let id = UUID()
        let image: NSImage
        let label: String
    }

    struct ToastMessage: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    struct AspectPreset: Identifiable {
        let id: String
        let title: String
        let ratio: CGFloat
    }

    enum CenteringSource: Sendable {
        case foregroundMask
    }

    enum BackgroundRemovalMode: Equatable {
        case isolateSubjectAI
        case solidColor
    }

    enum AppIconShape: String, CaseIterable, Identifiable {
        case apple
        case classic
        case round
        case square

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apple: "Apple"
            case .classic: "Classic"
            case .round: "Round"
            case .square: "Square"
            }
        }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case png
        case jpg

        var id: String { rawValue }

        var title: String {
            switch self {
            case .png: "PNG"
            case .jpg: "JPG"
            }
        }

        var fileExtension: String {
            rawValue
        }
    }

    enum RemoveBackgroundError: LocalizedError {
        case noMaskObservation
        case noForegroundSubject
        case renderingFailed

        var errorDescription: String? {
            switch self {
            case .noMaskObservation:
                return "No mask observation returned"
            case .noForegroundSubject:
                return "No foreground subject detected"
            case .renderingFailed:
                return "Mask rendering failed"
            }
        }
    }

    enum SolidBackgroundError: LocalizedError {
        case unsupportedImage
        case noEdgeColorDetected
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedImage:
                return "Unsupported image format"
            case .noEdgeColorDetected:
                return "Could not detect edge background color"
            case .renderFailed:
                return "Failed to render output image"
            }
        }
    }

    enum BackgroundStyle: String, CaseIterable, Identifiable {
        case original
        case aurora
        case sunset
        case ocean
        case graphite
        case solid

        var id: String { rawValue }

        var title: String {
            switch self {
            case .original: "Original"
            case .aurora: "Aurora"
            case .sunset: "Sunset"
            case .ocean: "Ocean"
            case .graphite: "Graphite"
            case .solid: "Solid"
            }
        }

        var gradient: LinearGradient {
            switch self {
            case .original:
                return LinearGradient(
                    colors: [Color(red: 0.17, green: 0.16, blue: 0.21), Color(red: 0.10, green: 0.10, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .aurora:
                return LinearGradient(
                    colors: [Color(red: 0.24, green: 0.16, blue: 0.60), Color(red: 0.06, green: 0.66, blue: 0.67)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sunset:
                return LinearGradient(
                    colors: [Color(red: 1.0, green: 0.52, blue: 0.33), Color(red: 0.98, green: 0.22, blue: 0.47)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .ocean:
                return LinearGradient(
                    colors: [Color(red: 0.10, green: 0.34, blue: 0.77), Color(red: 0.11, green: 0.74, blue: 0.69)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .graphite:
                return LinearGradient(
                    colors: [Color(red: 0.20, green: 0.22, blue: 0.28), Color(red: 0.07, green: 0.08, blue: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .solid:
                return LinearGradient(colors: [Color.black, Color.black], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}
