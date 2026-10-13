// Encode genuine engine PNG frames; no interpolation, repainting, or extra frames.
// swift -module-cache-path /private/tmp/foxfire-swift-cache pack_video.swift \
//   /private/tmp/fox-final-movement-frames /absolute/path/preview-walk.mp4
import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO

enum PackingError: Error { case message(String) }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw PackingError.message(message) }
}
func loadPNG(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw PackingError.message("Cannot load PNG: \(url.path)")
    }
    return image
}
func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw PackingError.message("Cannot create validation PNG")
    }
    CGImageDestinationAddImage(destination, image, nil)
    try require(CGImageDestinationFinalize(destination), "Cannot finish validation PNG")
}
func rgbaBytes(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    try bytes.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
              bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw PackingError.message("Cannot create comparison context")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return bytes
}

func run() throws {
    let args = CommandLine.arguments
    try require(args.count == 3, "Expected input frame directory and output MP4 path")
    let sourceDirectory = URL(fileURLWithPath: args[1], isDirectory: true)
    let destination = URL(fileURLWithPath: args[2])
    let frameCount = 120
    let fps: Int32 = 15
    let width = 1440
    let height = 900
    let manager = FileManager.default
    try require(!manager.fileExists(atPath: destination.path), "Output already exists; preserve it and choose a new output path")
    let firstURL = sourceDirectory.appendingPathComponent("frame-0000.png")
    let originalFirst = try loadPNG(firstURL)
    try require(originalFirst.width == width && originalFirst.height == height, "Unexpected source dimensions")
    let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 5_000_000,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: fps,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoAllowFrameReorderingKey: false
        ]
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
    try require(writer.canAdd(input), "Cannot add video track")
    writer.add(input)
    try require(writer.startWriting(), "Cannot start writer: \(String(describing: writer.error))")
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { throw PackingError.message("Pixel-buffer pool missing") }
    for index in 0..<frameCount {
        try autoreleasepool {
            let sourceURL = sourceDirectory.appendingPathComponent(String(format: "frame-%04d.png", index))
            let image = try loadPNG(sourceURL)
            try require(image.width == width && image.height == height, "Source size mismatch at frame \(index)")
            var optionalBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard result == kCVReturnSuccess, let buffer = optionalBuffer else {
                throw PackingError.message("Cannot allocate frame \(index)")
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                CVPixelBufferUnlockBaseAddress(buffer, [])
                throw PackingError.message("Cannot create frame bitmap context")
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            let deadline = Date().addingTimeInterval(30)
            while !input.isReadyForMoreMediaData {
                try require(writer.status == .writing && Date() < deadline, "Writer stalled: \(String(describing: writer.error))")
                Thread.sleep(forTimeInterval: 0.005)
            }
            try require(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: fps)),
                        "Cannot append frame \(index): \(String(describing: writer.error))")
        }
    }
    writer.endSession(atSourceTime: CMTime(value: Int64(frameCount), timescale: fps))
    input.markAsFinished()
    let complete = DispatchSemaphore(value: 0)
    writer.finishWriting { complete.signal() }
    try require(complete.wait(timeout: .now() + 60) == .success, "Finalization timed out")
    try require(writer.status == .completed, "Video export failed: \(String(describing: writer.error))")

    // Decode every frame to confirm the actual file, not just planned settings.
    let asset = AVURLAsset(url: destination)
    guard let track = asset.tracks(withMediaType: .video).first else { throw PackingError.message("No encoded video track") }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(output)
    try require(reader.startReading(), "Cannot decode exported video")
    var decoded = 0
    var firstPTS: Double = -1
    var lastPTS: Double = -1
    while let sample = output.copyNextSampleBuffer() {
        let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
        if decoded == 0 { firstPTS = time }
        lastPTS = time
        decoded += 1
    }
    try require(reader.status == .completed && decoded == frameCount, "Decoded frame-count mismatch: \(decoded)")
    try require(abs(asset.duration.seconds - 8.0) < 0.001, "Duration is not 8 seconds")
    try require(track.naturalSize == CGSize(width: width, height: height), "Encoded dimensions mismatch")
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let decodedFirst = try generator.copyCGImage(at: .zero, actualTime: nil)
    let validationImage = URL(fileURLWithPath: "/private/tmp/foxfire-video-first-frame.png")
    try writePNG(decodedFirst, to: validationImage)
    let originalPixels = try rgbaBytes(originalFirst, width: width, height: height)
    let decodedPixels = try rgbaBytes(decodedFirst, width: width, height: height)
    var directError: Double = 0
    var invertedError: Double = 0
    var sumA: Double = 0, sumB: Double = 0, sumC: Double = 0
    var sumAA: Double = 0, sumBB: Double = 0, sumCC: Double = 0
    var sumAB: Double = 0, sumAC: Double = 0
    for y in stride(from: 0, to: height, by: 5) {
        for x in stride(from: 0, to: width, by: 5) {
            for channel in 0..<3 {
                let index = (y * width + x) * 4 + channel
                let inverted = ((height - 1 - y) * width + x) * 4 + channel
                directError += abs(Double(originalPixels[index]) - Double(decodedPixels[index]))
                invertedError += abs(Double(originalPixels[index]) - Double(decodedPixels[inverted]))
                let a = Double(originalPixels[index]), b = Double(decodedPixels[index]), c = Double(decodedPixels[inverted])
                sumA += a; sumB += b; sumC += c
                sumAA += a*a; sumBB += b*b; sumCC += c*c
                sumAB += a*b; sumAC += a*c
            }
        }
    }
    let sampleValues = Double(((width + 4) / 5) * ((height + 4) / 5) * 3)
    directError /= sampleValues
    invertedError /= sampleValues
    // Flat, bright close-ups have little flip error, so the old MAE ratio
    // falsely rejected correctly oriented footage after Rec709/sRGB conversion.
    // Check spatial correlation, plus an absolute color-error bound, instead.
    let varianceA = sumAA - sumA*sumA/sampleValues
    let directCorrelation = (sumAB - sumA*sumB/sampleValues) / sqrt(max(1, varianceA*(sumBB-sumB*sumB/sampleValues)))
    let flippedCorrelation = (sumAC - sumA*sumC/sampleValues) / sqrt(max(1, varianceA*(sumCC-sumC*sumC/sampleValues)))
    print("Frame QA MAE=\(directError), flipped MAE=\(invertedError), correlation=\(directCorrelation), flipped correlation=\(flippedCorrelation)")
    try require(directError < 12 && directCorrelation > 0.99 && directCorrelation > flippedCorrelation + 0.2, "First-frame orientation/color check failed")
    let size = try manager.attributesOfItem(atPath: destination.path)[.size] as! NSNumber
    let report: [String: Any] = [
        "encoder": "macOS AVFoundation / H.264 High", "source": "120 original engine PNG frames; no interpolation",
        "file": destination.lastPathComponent, "bytes": size, "width": width, "height": height,
        "fps": track.nominalFrameRate, "duration_seconds": asset.duration.seconds,
        "decoded_frames": decoded, "first_pts_seconds": firstPTS, "last_pts_seconds": lastPTS,
        "first_frame_rgb_mean_absolute_error_0_255": directError,
        "first_frame_vertical_flip_error_0_255": invertedError,
        "first_frame_direct_correlation": directCorrelation,
        "first_frame_flipped_correlation": flippedCorrelation,
        "first_frame_orientation_passed": true,
        "validation_png": validationImage.path, "audio": false,
        "scope": "Local encoding and all-frame decode verification; not a claim of new gameplay or animation acceptance."
    ]
    let reportDirectory = destination.deletingLastPathComponent().appendingPathComponent("reports", isDirectory: true)
    try manager.createDirectory(at: reportDirectory, withIntermediateDirectories: true)
    let reportData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    try reportData.write(to: reportDirectory.appendingPathComponent("video.json"))
    print(String(data: reportData, encoding: .utf8)!)
}
do { try run() } catch {
    fputs("Video packing failed: \(error)\n", stderr)
    exit(1)
}
