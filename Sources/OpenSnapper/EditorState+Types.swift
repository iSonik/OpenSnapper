import AppKit
import CoreGraphics
import Foundation
import SwiftUI

extension EditorState {
    enum AnnotationTool: String, CaseIterable, Identifiable, Hashable {
        case none
        case hand
        case box
        case arrow
        case lupe
        case draw
        case text

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: "Cursor"
            case .hand: "Hand"
            case .box: "Box"
            case .arrow: "Arrow"
            case .lupe: "Magnify"
            case .draw: "Draw"
            case .text: "Text"
            }
        }

        var symbolName: String {
            switch self {
            case .none: "cursorarrow"
            case .hand: "hand.raised"
            case .box: "square.dashed"
            case .arrow: "arrow.up.right"
            case .lupe: "magnifyingglass"
            case .draw: "scribble"
            case .text: "textformat"
            }
        }
    }

    enum AnnotationStylePreset: String, CaseIterable, Identifiable, Hashable {
        case callout
        case subtle
        case warning
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .callout: "Callout"
            case .subtle: "Subtle"
            case .warning: "Warning"
            case .custom: "Custom"
            }
        }
    }

    enum AnnotationBoxCorner: CaseIterable, Hashable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    enum AnnotationTextHandleSide: Hashable {
        case left
        case right
        case top
        case bottom
    }

    enum AnnotationTextAlignment: String, CaseIterable, Hashable {
        case leading
        case center
        case trailing

        var title: String {
            switch self {
            case .leading: "Left"
            case .center: "Center"
            case .trailing: "Right"
            }
        }

        var symbolName: String {
            switch self {
            case .leading: "text.alignleft"
            case .center: "text.aligncenter"
            case .trailing: "text.alignright"
            }
        }

        var swiftUITextAlignment: TextAlignment {
            switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }

        var frameAlignment: Alignment {
            switch self {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }

        var nsTextAlignment: NSTextAlignment {
            switch self {
            case .leading: .left
            case .center: .center
            case .trailing: .right
            }
        }
    }

    enum AnnotationHitTarget: Hashable {
        case body(UUID)
        case boxCorner(UUID, AnnotationBoxCorner)
        case arrowStart(UUID)
        case arrowEnd(UUID)
        case arrowBend(UUID)
        case lupeRadius(UUID)
        case drawMove(UUID)
        case textHandle(UUID, AnnotationTextHandleSide)

        var annotationID: UUID {
            switch self {
            case .body(let id),
                .arrowStart(let id),
                .arrowEnd(let id),
                .arrowBend(let id),
                .lupeRadius(let id),
                .drawMove(let id),
                .textHandle(let id, _):
                return id
            case .boxCorner(let id, _):
                return id
            }
        }
    }

    struct Annotation: Identifiable, Equatable {
        enum Kind: Equatable {
            case box
            case arrow
            case lupe
            case draw
            case text

            var title: String {
                switch self {
                case .box: "Box"
                case .arrow: "Arrow"
                case .lupe: "Magnify"
                case .draw: "Draw"
                case .text: "Text"
                }
            }
        }

        let id: UUID
        let kind: Kind
        let stylePreset: AnnotationStylePreset
        let start: CGPoint
        let end: CGPoint
        let text: String?
        let textBoxWidth: CGFloat?
        let textBoxHeight: CGFloat?
        let controlPoint: CGPoint?
        let points: [CGPoint]

        init(
            id: UUID,
            kind: Kind,
            stylePreset: AnnotationStylePreset,
            start: CGPoint,
            end: CGPoint,
            text: String?,
            textBoxWidth: CGFloat?,
            textBoxHeight: CGFloat?,
            controlPoint: CGPoint? = nil,
            points: [CGPoint] = []
        ) {
            self.id = id
            self.kind = kind
            self.stylePreset = stylePreset
            self.start = start
            self.end = end
            self.text = text
            self.textBoxWidth = textBoxWidth
            self.textBoxHeight = textBoxHeight
            self.controlPoint = controlPoint
            self.points = points
        }
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
        let isCustomLayoutMode: Bool
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
        let annotationStrokeWidth: CGFloat
        let annotationBoxFillColor: Color
        let annotationBoxFillOpacity: Double
        let annotationBoxCornerRadius: CGFloat
        let annotationDrawAutoSmooth: Bool
        let annotationTextDefaultFontColor: Color
        let annotationTextDefaultBackgroundColor: Color
        let annotationTextDefaultFontSize: CGFloat
        let annotationTextDefaultAlignment: AnnotationTextAlignment
        let annotationTextFontColorOverrides: [UUID: Color]
        let annotationTextBackgroundColorOverrides: [UUID: Color]
        let annotationTextFontSizeOverrides: [UUID: CGFloat]
        let annotationTextAlignmentOverrides: [UUID: AnnotationTextAlignment]
        let annotationColorOverrides: [UUID: Color]
        let annotationStrokeWidthOverrides: [UUID: CGFloat]
        let annotationBoxFillColorOverrides: [UUID: Color]
        let annotationBoxFillOpacityOverrides: [UUID: Double]
        let annotationBoxCornerRadiusOverrides: [UUID: CGFloat]
        let annotationDrawAutoSmoothOverrides: [UUID: Bool]
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
        case mint
        case sky
        case sunset
        case rose
        case ocean
        case lagoon
        case ember
        case sand
        case neon
        case graphite
        case solid

        var id: String { rawValue }

        var title: String {
            switch self {
            case .original: "Original"
            case .aurora: "Aurora"
            case .mint: "Mint"
            case .sky: "Sky"
            case .sunset: "Sunset"
            case .rose: "Rose"
            case .ocean: "Ocean"
            case .lagoon: "Lagoon"
            case .ember: "Ember"
            case .sand: "Sand"
            case .neon: "Neon"
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
            case .mint:
                return LinearGradient(
                    colors: [Color(red: 0.73, green: 0.96, blue: 0.86), Color(red: 0.20, green: 0.73, blue: 0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sky:
                return LinearGradient(
                    colors: [Color(red: 0.62, green: 0.84, blue: 1.0), Color(red: 0.34, green: 0.55, blue: 0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sunset:
                return LinearGradient(
                    colors: [Color(red: 1.0, green: 0.52, blue: 0.33), Color(red: 0.98, green: 0.22, blue: 0.47)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .rose:
                return LinearGradient(
                    colors: [Color(red: 0.99, green: 0.75, blue: 0.86), Color(red: 0.84, green: 0.26, blue: 0.54)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .ocean:
                return LinearGradient(
                    colors: [Color(red: 0.10, green: 0.34, blue: 0.77), Color(red: 0.11, green: 0.74, blue: 0.69)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .lagoon:
                return LinearGradient(
                    colors: [Color(red: 0.08, green: 0.58, blue: 0.73), Color(red: 0.18, green: 0.89, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .ember:
                return LinearGradient(
                    colors: [Color(red: 0.95, green: 0.44, blue: 0.14), Color(red: 0.48, green: 0.06, blue: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sand:
                return LinearGradient(
                    colors: [Color(red: 0.93, green: 0.84, blue: 0.66), Color(red: 0.78, green: 0.62, blue: 0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .neon:
                return LinearGradient(
                    colors: [Color(red: 0.16, green: 0.96, blue: 0.74), Color(red: 0.14, green: 0.20, blue: 0.74)],
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
