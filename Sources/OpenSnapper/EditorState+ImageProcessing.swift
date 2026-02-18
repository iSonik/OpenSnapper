import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import Foundation
import Vision

extension EditorState {
    struct RemoveBackgroundOutput {
        let image: CGImage
        let subjectCenter: CGPoint
    }

    @available(macOS 14.0, *)
    nonisolated static func cutoutForeground(from cgImage: CGImage) throws -> RemoveBackgroundOutput {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw RemoveBackgroundError.noMaskObservation
        }

        let instances = observation.allInstances
        guard !instances.isEmpty else {
            throw RemoveBackgroundError.noForegroundSubject
        }
        let maskBuffer = try observation.generateScaledMaskForImage(forInstances: instances, from: handler)
        let subjectCenter = weightedCenterFromMask(maskBuffer) ?? CGPoint(x: 0.5, y: 0.5)

        let inputImage = CIImage(cgImage: cgImage)
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let clearImage = CIImage(color: .clear).cropped(to: inputImage.extent)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = inputImage
        filter.maskImage = maskImage
        filter.backgroundImage = clearImage

        guard
            let outputImage = filter.outputImage,
            let outputCGImage = CIContext().createCGImage(outputImage, from: inputImage.extent)
        else {
            throw RemoveBackgroundError.renderingFailed
        }

        if let trimmed = trimTransparentBounds(from: outputCGImage) {
            return RemoveBackgroundOutput(image: trimmed, subjectCenter: CGPoint(x: 0.5, y: 0.5))
        }

        return RemoveBackgroundOutput(image: outputCGImage, subjectCenter: subjectCenter)
    }

    @available(macOS 14.0, *)
    nonisolated static func detectSubjectCenter(from cgImage: CGImage) throws -> CGPoint? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        let instances = observation.allInstances
        guard !instances.isEmpty else {
            return nil
        }

        let maskBuffer = try observation.generateScaledMaskForImage(forInstances: instances, from: handler)
        return weightedCenterFromMask(maskBuffer)
    }

    nonisolated static func detectSensitiveTextRegions(from cgImage: CGImage) throws -> [CGRect] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        var regions: [CGRect] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            if isSensitiveText(text) {
                let expanded = observation.boundingBox.insetBy(dx: -0.008, dy: -0.012).standardized
                let clamped = CGRect(
                    x: max(0, min(1, expanded.minX)),
                    y: max(0, min(1, expanded.minY)),
                    width: max(0, min(1, expanded.maxX) - max(0, min(1, expanded.minX))),
                    height: max(0, min(1, expanded.maxY) - max(0, min(1, expanded.minY)))
                )
                if clamped.width > 0.001, clamped.height > 0.001 {
                    regions.append(clamped)
                }
            }
        }
        return regions
    }

    private nonisolated static func isSensitiveText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let patterns = [
            "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
            "(?:\\+?\\d[\\d\\s().-]{7,}\\d)",
            "\\b(?:sk|pk)_(?:live|test)_[A-Za-z0-9]{16,}\\b",
            "\\bAKIA[0-9A-Z]{16}\\b",
            "\\bAIza[0-9A-Za-z\\-_]{35}\\b",
            "\\bghp_[A-Za-z0-9]{36}\\b",
            "\\b(?:eyJ[A-Za-z0-9_\\-]+=*\\.[A-Za-z0-9_\\-]+=*\\.[A-Za-z0-9_\\-+/=]*)\\b",
            "(?i)\\b(?:api[_ -]?key|token|secret|password)\\b\\s*[:=]\\s*\\S+"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return true
                }
            }
        }

        return false
    }

    private struct EdgeColorAccumulator {
        var count: Int = 0
        var sumR: CGFloat = 0
        var sumG: CGFloat = 0
        var sumB: CGFloat = 0
    }

    nonisolated static func removeSolidBackgroundFromEdges(
        from cgImage: CGImage,
        tolerance: CGFloat,
        softness: CGFloat
    ) throws -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else {
            throw SolidBackgroundError.unsupportedImage
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = Data(count: bytesPerRow * height)

        let rendered = data.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered else {
            throw SolidBackgroundError.renderFailed
        }

        var pixels = [UInt8](data)
        guard let targetColor = detectDominantEdgeColor(in: pixels, width: width, height: height, bytesPerRow: bytesPerRow) else {
            throw SolidBackgroundError.noEdgeColorDetected
        }

        applyEdgeConnectedBackgroundRemoval(
            to: &pixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            targetColor: targetColor,
            tolerance: max(0, tolerance),
            softness: max(0, softness)
        )

        let outputData = Data(pixels)
        guard let provider = CGDataProvider(data: outputData as CFData) else {
            throw SolidBackgroundError.renderFailed
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let outputCGImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw SolidBackgroundError.renderFailed
        }

        if let trimmed = trimTransparentBounds(from: outputCGImage) {
            return trimmed
        }
        return outputCGImage
    }

    private nonisolated static func detectDominantEdgeColor(
        in pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var bins: [Int: EdgeColorAccumulator] = [:]
        var totalSamples = 0

        func samplePixel(_ x: Int, _ y: Int) {
            let offset = (y * bytesPerRow) + (x * 4)
            let (_, r, g, b) = normalizedRGBA(in: pixels, offset: offset)
            let alpha = CGFloat(pixels[offset + 3]) / 255.0
            guard alpha > 0.08 else { return }

            let qr = Int((r * 15).rounded())
            let qg = Int((g * 15).rounded())
            let qb = Int((b * 15).rounded())
            let key = (qr << 8) | (qg << 4) | qb

            var accumulator = bins[key] ?? EdgeColorAccumulator()
            accumulator.count += 1
            accumulator.sumR += r
            accumulator.sumG += g
            accumulator.sumB += b
            bins[key] = accumulator
            totalSamples += 1
        }

        for x in 0..<width {
            samplePixel(x, 0)
            if height > 1 { samplePixel(x, height - 1) }
        }
        if height > 2 {
            for y in 1..<(height - 1) {
                samplePixel(0, y)
                if width > 1 { samplePixel(width - 1, y) }
            }
        }

        guard totalSamples > 0 else { return nil }
        guard let dominant = bins.max(by: { $0.value.count < $1.value.count }) else {
            return nil
        }

        let minimumDominance = max(10, Int(Double(totalSamples) * 0.12))
        guard dominant.value.count >= minimumDominance else {
            return nil
        }

        let count = max(1, dominant.value.count)
        return (
            r: dominant.value.sumR / CGFloat(count),
            g: dominant.value.sumG / CGFloat(count),
            b: dominant.value.sumB / CGFloat(count)
        )
    }

    private nonisolated static func applyEdgeConnectedBackgroundRemoval(
        to pixels: inout [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        targetColor: (r: CGFloat, g: CGFloat, b: CGFloat),
        tolerance: CGFloat,
        softness: CGFloat
    ) {
        let maxDistance = tolerance + softness
        var visited = [UInt8](repeating: 0, count: width * height)
        var queue: [Int] = []
        queue.reserveCapacity(width * 2 + height * 2)
        var head = 0

        func enqueueIfBackground(_ x: Int, _ y: Int) {
            let index = (y * width) + x
            if visited[index] == 1 { return }

            let offset = (y * bytesPerRow) + (x * 4)
            let alpha = CGFloat(pixels[offset + 3]) / 255.0
            let distance = colorDistance(in: pixels, offset: offset, targetColor: targetColor)
            guard alpha < 0.03 || distance <= maxDistance else { return }

            visited[index] = 1
            queue.append(index)
        }

        for x in 0..<width {
            enqueueIfBackground(x, 0)
            if height > 1 { enqueueIfBackground(x, height - 1) }
        }
        if height > 2 {
            for y in 1..<(height - 1) {
                enqueueIfBackground(0, y)
                if width > 1 { enqueueIfBackground(width - 1, y) }
            }
        }

        while head < queue.count {
            let index = queue[head]
            head += 1

            let x = index % width
            let y = index / width
            let offset = (y * bytesPerRow) + (x * 4)

            let alphaByte = pixels[offset + 3]
            if alphaByte > 0 {
                let distance = colorDistance(in: pixels, offset: offset, targetColor: targetColor)
                if distance <= maxDistance {
                    let oldAlpha = CGFloat(alphaByte)
                    let newAlpha: CGFloat
                    if distance <= tolerance {
                        newAlpha = 0
                    } else if softness > 0 {
                        let normalized = (distance - tolerance) / softness
                        newAlpha = oldAlpha * min(max(normalized, 0), 1)
                    } else {
                        newAlpha = oldAlpha
                    }

                    let clampedAlpha = UInt8(clamping: Int(newAlpha.rounded()))
                    if clampedAlpha == 0 {
                        pixels[offset] = 0
                        pixels[offset + 1] = 0
                        pixels[offset + 2] = 0
                        pixels[offset + 3] = 0
                    } else if clampedAlpha < alphaByte {
                        let scale = CGFloat(clampedAlpha) / oldAlpha
                        pixels[offset] = UInt8(clamping: Int((CGFloat(pixels[offset]) * scale).rounded()))
                        pixels[offset + 1] = UInt8(clamping: Int((CGFloat(pixels[offset + 1]) * scale).rounded()))
                        pixels[offset + 2] = UInt8(clamping: Int((CGFloat(pixels[offset + 2]) * scale).rounded()))
                        pixels[offset + 3] = clampedAlpha
                    }
                }
            }

            if x > 0 { enqueueIfBackground(x - 1, y) }
            if x + 1 < width { enqueueIfBackground(x + 1, y) }
            if y > 0 { enqueueIfBackground(x, y - 1) }
            if y + 1 < height { enqueueIfBackground(x, y + 1) }
        }
    }

    private nonisolated static func normalizedRGBA(
        in pixels: [UInt8],
        offset: Int
    ) -> (a: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat) {
        let alpha = CGFloat(pixels[offset + 3]) / 255.0
        guard alpha > 0.0001 else {
            return (0, 0, 0, 0)
        }

        let premultipliedR = CGFloat(pixels[offset]) / 255.0
        let premultipliedG = CGFloat(pixels[offset + 1]) / 255.0
        let premultipliedB = CGFloat(pixels[offset + 2]) / 255.0
        let r = min(max(premultipliedR / alpha, 0), 1)
        let g = min(max(premultipliedG / alpha, 0), 1)
        let b = min(max(premultipliedB / alpha, 0), 1)
        return (alpha, r, g, b)
    }

    private nonisolated static func colorDistance(
        in pixels: [UInt8],
        offset: Int,
        targetColor: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) -> CGFloat {
        let (_, r, g, b) = normalizedRGBA(in: pixels, offset: offset)
        let dr = r - targetColor.r
        let dg = g - targetColor.g
        let db = b - targetColor.b
        return sqrt((dr * dr) + (dg * dg) + (db * db)) / 1.7320508
    }

    private nonisolated static func weightedCenterFromMask(_ maskBuffer: CVPixelBuffer) -> CGPoint? {
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)

        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var totalWeight: CGFloat = 0

        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let value = CGFloat(row[x]) / 255.0
                if value > 0.01 {
                    weightedX += value * (CGFloat(x) + 0.5)
                    weightedY += value * (CGFloat(y) + 0.5)
                    totalWeight += value
                }
            }
        }

        guard totalWeight > 0 else {
            return nil
        }

        let normalizedX = (weightedX / totalWeight) / CGFloat(width)
        let normalizedTopOriginY = (weightedY / totalWeight) / CGFloat(height)
        let normalizedBottomOriginY = 1 - normalizedTopOriginY
        return CGPoint(x: normalizedX, y: normalizedBottomOriginY)
    }

    private nonisolated static func trimTransparentBounds(from cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else { return cgImage }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = Data(count: bytesPerRow * height)

        let rendered = data.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered else { return nil }

        let alphaThreshold: UInt8 = 4
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let index = (y * bytesPerRow) + (x * bytesPerPixel)
                    let alpha = base[index + 3]
                    if alpha > alphaThreshold {
                        if x < minX { minX = x }
                        if y < minY { minY = y }
                        if x > maxX { maxX = x }
                        if y > maxY { maxY = y }
                    }
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: (maxX - minX + 1),
            height: (maxY - minY + 1)
        )
        return cgImage.cropping(to: cropRect)
    }
}
