//
//  DiceScanView.swift
//  RollnWrite – App
//
//  "Scan dice" (issue #56): read the player's physical dice colours from a
//  photo instead of eyeballing a `ColorPicker`. Two equally-weighted sources —
//  an in-app camera capture and a photo-library picker (the library path is
//  required for testing: the Simulator has no camera) — feed the same
//  sampling screen. The screen shows the photo fit-to-screen with the six
//  palette slots as a row of chips; tapping the photo samples a small region
//  under the tap into the active slot and auto-advances. Apply writes the six
//  colours to `DiceTheme.shared.palette` in one assignment (its `didSet`
//  persists and recolours every open board); Cancel discards everything.
//
//  DICE LOCATOR (v2): as soon as the sampling screen appears, an on-device
//  Vision pass (`VNDetectRectanglesRequest`, tuned for square-ish dice) looks
//  for dice in the photo, runs the SAME region-average sampler at each
//  located box's centre, and pre-fills slots 1…N in reading order (top→bottom,
//  left→right). Numbered markers show what was auto-read. Tapping remains the
//  correction layer — it always worked, and is the silent fallback whenever
//  the locator finds fewer than 2 candidates. Runs off the main thread so the
//  photo and tap gesture are interactive immediately.
//
//  App layer only: this is a Settings feature (composition), so it lives
//  here, never in Core — `DiceTheme` itself is untouched.
//

import SwiftUI
import UIKit
import PhotosUI
import Vision

// MARK: - Entry point (source choice)

/// Presented from Settings' dice-colours section. Offers the camera (hidden
/// on the Simulator / devices without one) and the photo library as equal
/// alternatives, then hands the chosen `UIImage` to `DiceSampleView`.
struct DiceScanView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isLoadingPhoto = false
    @State private var pickedImage: UIImage?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "die.face.5")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)

                Text("Scan your dice")
                    .font(.title2.weight(.semibold))

                Text("Take or choose a photo of your dice, then tap each one to read its colour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    if cameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take a photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingPhoto)
                }
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Scan dice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { image in
                    showCamera = false
                    if let image { pickedImage = image }
                }
            }
            .onChange(of: photoPickerItem) { _, newValue in
                guard let newValue else { return }
                isLoadingPhoto = true
                Task {
                    defer { isLoadingPhoto = false }
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pickedImage = image
                    }
                }
            }
            .fullScreenCover(item: $pickedImage.asIdentifiableBinding) { wrapped in
                DiceSampleView(image: wrapped.value) {
                    pickedImage = nil
                    dismiss()
                } onCancel: {
                    pickedImage = nil
                }
            }
        }
    }
}

// MARK: - Optional → Identifiable bridge

/// `fullScreenCover(item:)` needs `Identifiable`; a plain `UIImage?` isn't, so
/// this wraps it just for the presentation without touching `UIImage` itself.
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let value: UIImage
}

private extension Binding where Value == UIImage? {
    /// Bridges this optional binding to an `Identifiable` one; setting the
    /// wrapped value to `nil` (e.g. the sheet's own dismiss) clears the
    /// original optional too.
    var asIdentifiableBinding: Binding<IdentifiableImage?> {
        Binding<IdentifiableImage?>(
            get: { wrappedValue.map(IdentifiableImage.init) },
            set: { wrappedValue = $0?.value }
        )
    }
}

// MARK: - Camera capture

/// Minimal `UIImagePickerController` wrapper for a single photo capture.
/// Chosen over a hand-rolled `AVCaptureSession` for v1 simplicity — it gets
/// the standard camera UI (shutter, retake/use-photo) for free.
private struct CameraCaptureView: UIViewControllerRepresentable {
    /// `nil` means the user cancelled without capturing anything.
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

// MARK: - Sampling screen

/// The photo, fit-to-screen, with the six palette slots shown as a row of
/// chips (pre-filled with the CURRENT palette, then possibly re-filled by the
/// dice locator once it finishes). Tapping the photo samples the colour under
/// the tap into the active slot and auto-advances; tapping a chip re-selects
/// that slot. Apply writes all six colours to `DiceTheme.shared.palette` in
/// one assignment; Cancel discards.
private struct DiceSampleView: View {
    let image: UIImage
    let onApply: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Working copy, pre-filled from the current theme; only written back to
    /// `DiceTheme.shared.palette` on Apply.
    @State private var slots: [RGBAColor] = DiceTheme.shared.palette
    @State private var activeSlot = 0

    /// The upright `CGImage` sampling reads from (see `normalizedCGImage`
    /// doc for why raw `image.cgImage` is unsafe to use directly).
    @State private var uprightImage: CGImage?

    /// The photo's on-screen frame, updated by the `GeometryReader` each time
    /// `.scaledToFit` recomputes its letterboxing — needed to map a tap point
    /// (or a locator box) back into image space.
    @State private var displayedImageFrame: CGRect = .zero

    /// True while the Vision locator is running, so the UI can show a subtle
    /// progress state without blocking the photo or the tap gesture.
    @State private var isLocating = true

    /// Accepted locator boxes, in image-pixel space (top-left origin, same
    /// space the tap sampler uses), in the order they filled slots 1…N.
    /// `slot` is that fill index (0-based); nil once the user overwrites that
    /// slot with a manual tap, which dims/removes its number (§4).
    @State private var markers: [DiceMarker] = []

    private let slotLabels = ["Die 1", "Die 2", "Die 3", "Die 4", "Die 5", "Die 6"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)

                        ForEach(markers) { marker in
                            markerOverlay(marker)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onAppear {
                        displayedImageFrame = fittedImageFrame(in: geo.size)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        displayedImageFrame = fittedImageFrame(in: newSize)
                    }
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            sample(atViewPoint: value.location)
                        }
                    )
                }
                .background(Color.black)

                statusLine
                    .padding(.top, 12)

                chipRow
                    .padding(.vertical, 16)
                    .background(.bar)
            }
            .navigationTitle("Sample dice colours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        DiceTheme.shared.palette = slots
                        onApply()
                    }
                }
            }
            .task {
                let upright = Self.normalizedCGImage(from: image)
                uprightImage = upright
                await locateDice(in: upright)
            }
        }
    }

    /// A subtle "Looking for dice…" progress line while the locator runs,
    /// then either "N dice found — tap to adjust" once it lands a prefill, or
    /// the original plain instruction (it found nothing and silently fell
    /// back to the pure tap flow).
    private var statusLine: some View {
        Group {
            if isLocating {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Looking for dice…")
                }
            } else if !markers.isEmpty {
                Text("\(markers.count) dice found — tap to adjust")
            } else {
                Text("Tap each die in the photo to sample its colour")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var chipRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<DiceTheme.slotCount, id: \.self) { i in
                Button {
                    activeSlot = i
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(slots[i].color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().strokeBorder(
                                    activeSlot == i ? Color.accentColor : Color.secondary.opacity(0.4),
                                    lineWidth: activeSlot == i ? 3 : 1
                                )
                            )
                        Text(verbatim: "\(i + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(slotLabels[i]))
            }
        }
    }

    // MARK: Coordinate mapping (view space ↔ image pixel space)

    /// The frame `.scaledToFit` gives the image inside a `size`-sized
    /// container: the image is scaled uniformly by
    /// `min(size.width / image.width, size.height / image.height)`, then
    /// centred — producing letterbox bars on whichever axis has slack. This
    /// mirrors that math so a tap point (or a marker box) can be converted
    /// between view space and image space. Shared by taps and markers so the
    /// two never drift apart.
    private func fittedImageFrame(in size: CGSize) -> CGRect {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale
        let originX = (size.width - fittedWidth) / 2
        let originY = (size.height - fittedHeight) / 2
        return CGRect(x: originX, y: originY, width: fittedWidth, height: fittedHeight)
    }

    /// Converts a rect in upright-image PIXEL space (top-left origin) to the
    /// displayed view's local space, using the same `displayedImageFrame`
    /// scale/offset the tap sampler inverts in `sample(atViewPoint:)`.
    private func viewRect(forImagePixelRect rect: CGRect, cgImage: CGImage) -> CGRect {
        let scaleX = displayedImageFrame.width / CGFloat(cgImage.width)
        let scaleY = displayedImageFrame.height / CGFloat(cgImage.height)
        return CGRect(
            x: displayedImageFrame.minX + rect.minX * scaleX,
            y: displayedImageFrame.minY + rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    /// Samples the colour under a tap (in the `GeometryReader`'s local view
    /// space), fills the active slot, and auto-advances to the next slot.
    /// Also clears any locator marker that was numbering the active slot: a
    /// manual re-sample means the auto-read no longer describes that slot.
    private func sample(atViewPoint point: CGPoint) {
        guard let cgImage = uprightImage else { return }
        guard displayedImageFrame.contains(point) else { return }

        // View point → normalized 0…1 position within the displayed image →
        // pixel position in the upright CGImage (whose pixel size may differ
        // from the UIImage's *point* size by `image.scale`, so derive it from
        // the CGImage's own width/height rather than assuming a 1:1 ratio).
        let fx = (point.x - displayedImageFrame.minX) / displayedImageFrame.width
        let fy = (point.y - displayedImageFrame.minY) / displayedImageFrame.height
        let pixelX = fx * CGFloat(cgImage.width)
        let pixelY = fy * CGFloat(cgImage.height)

        guard let averaged = Self.averageColor(
            in: cgImage,
            centeredAt: CGPoint(x: pixelX, y: pixelY),
            side: Self.defaultRegionSide(for: cgImage)
        ) else { return }

        slots[activeSlot] = averaged
        markers.removeAll { $0.slot == activeSlot }
        activeSlot = (activeSlot + 1) % DiceTheme.slotCount
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// The tap sampler's region size: ~2% of the smaller image dimension,
    /// clamped to a sane 15–25px range, so a single noisy pixel (a highlight,
    /// a pip) doesn't skew the read.
    private static func defaultRegionSide(for cgImage: CGImage) -> CGFloat {
        let smallerDimension = CGFloat(min(cgImage.width, cgImage.height))
        return max(15, min(25, smallerDimension * 0.02))
    }

    // MARK: Dice locator (Vision)

    /// One accepted locator box, in image-pixel space, plus the slot it
    /// filled — drawn as a numbered marker over the photo.
    private struct DiceMarker: Identifiable {
        let id = UUID()
        let rect: CGRect     // top-left-origin pixel space, same as the sampler
        let slot: Int        // 0-based slot this marker filled
    }

    @ViewBuilder
    private func markerOverlay(_ marker: DiceMarker) -> some View {
        if let cgImage = uprightImage {
            let rect = viewRect(forImagePixelRect: marker.rect, cgImage: cgImage)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.6), lineWidth: 4)
                )
                .frame(width: rect.width, height: rect.height)
                .overlay(alignment: .topLeading) {
                    Text(verbatim: "\(marker.slot + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .offset(x: 2, y: -10)
                }
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
    }

    /// Runs `VNDetectRectanglesRequest` off the main thread, filters the
    /// candidates down to plausible dice, samples each survivor's colour with
    /// the existing region-average sampler, and pre-fills slots 1…N. Fewer
    /// than 2 candidates is treated as "nothing found" and falls back
    /// silently to the pure tap flow — no error UI, since tapping already IS
    /// the fallback.
    private func locateDice(in cgImage: CGImage?) async {
        defer { isLocating = false }
        guard let cgImage else { return }

        let boxes = await Task.detached(priority: .userInitiated) {
            Self.detectDiceBoxes(in: cgImage)
        }.value

        guard boxes.count >= 2 else { return }

        let accepted = Array(boxes.prefix(DiceTheme.slotCount))
        var newSlots = slots
        var newMarkers: [DiceMarker] = []
        for (index, box) in accepted.enumerated() {
            guard let bodyColor = Self.dieBodyColor(in: cgImage, box: box) else { continue }
            newSlots[index] = bodyColor
            newMarkers.append(DiceMarker(rect: box, slot: index))
        }

        guard !newMarkers.isEmpty else { return }
        slots = newSlots
        markers = newMarkers
        activeSlot = newMarkers.count < DiceTheme.slotCount ? newMarkers.count : 0
    }

    /// Reads a located die's BODY colour while ignoring its pips. Fixed patch
    /// patterns fail here — faces 3 and 5 put pips exactly at the centre and
    /// diagonal offsets — so instead the box interior (inset 18% per side to
    /// stay off edges/shadows) is downsampled to a 12×12 bitmap and the pixel
    /// at the MEDIAN luminance is returned: pips cover well under half of any
    /// standard face, so the median pixel is always die body — dark pips on a
    /// light die sort below it, light pips on a dark die above it. Picking an
    /// actual pixel (rather than a per-channel median) guarantees the result
    /// is a colour that really exists on the die.
    private static func dieBodyColor(in cgImage: CGImage, box: CGRect) -> RGBAColor? {
        let inset = min(box.width, box.height) * 0.18
        let region = box.insetBy(dx: inset, dy: inset)
        guard region.width > 1, region.height > 1 else { return nil }

        let grid = 12
        var pixels = [UInt8](repeating: 0, count: grid * grid * 4)
        guard let context = CGContext(
            data: &pixels,
            width: grid,
            height: grid,
            bitsPerComponent: 8,
            bytesPerRow: grid * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Same top-left→CG-bottom-up flip as `averageColor` (see there), then
        // scale so exactly `region` fills the grid.
        let sx = CGFloat(grid) / region.width
        let sy = CGFloat(grid) / region.height
        let cgRegionY = CGFloat(cgImage.height) - region.maxY
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(
            x: -region.minX * sx,
            y: -cgRegionY * sy,
            width: CGFloat(cgImage.width) * sx,
            height: CGFloat(cgImage.height) * sy
        ))

        var samples: [(luma: Double, color: RGBAColor)] = []
        samples.reserveCapacity(grid * grid)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Double(pixels[i + 3])
            guard a > 0 else { continue }
            let c = RGBAColor(red: Double(pixels[i]) / a,
                              green: Double(pixels[i + 1]) / a,
                              blue: Double(pixels[i + 2]) / a,
                              alpha: 1)
            let luma = 0.299 * c.red + 0.587 * c.green + 0.114 * c.blue
            samples.append((luma, c))
        }
        guard !samples.isEmpty else { return nil }
        samples.sort { $0.luma < $1.luma }
        return samples[samples.count / 2].color
    }

    /// Vision pass: finds square-ish quadrilaterals plausibly matching dice,
    /// then post-filters for size consistency and de-duplicates overlaps.
    /// Runs synchronously on a background thread (Vision request handlers are
    /// blocking, non-async APIs) — callers dispatch this off the main actor.
    private static func detectDiceBoxes(in cgImage: CGImage) -> [CGRect] {
        let request = VNDetectRectanglesRequest()
        // Vision's aspect ratio is short-side/long-side, so dice (square, but
        // photographed at an angle) sit close to 1.0; 0.7 tolerates skew
        // without admitting long rectangular objects.
        request.minimumAspectRatio = 0.7
        request.maximumAspectRatio = 1.0
        // Small enough to catch a die in a wide table photo, not so small
        // that noise/pips themselves get proposed as dice.
        request.minimumSize = 0.05
        request.maximumObservations = 12
        request.minimumConfidence = 0.5
        // Dice are rarely photographed dead-on; a generous corner tolerance
        // (degrees) lets Vision accept perspective-skewed quads.
        request.quadratureTolerance = 20

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let observations = request.results, !observations.isEmpty else {
            return []
        }

        // Vision reports normalized boundingBox in a BOTTOM-left-origin unit
        // square (x,y ∈ 0…1, y=0 at the image's bottom edge — the inverse of
        // UIKit/CoreGraphics image space). The sampler and every other
        // coordinate in this file use TOP-left-origin pixel space, so:
        //   pixelX      = box.origin.x * imageWidth
        //   pixelY      = (1 - box.origin.y - box.height) * imageHeight
        //   pixelWidth  = box.width  * imageWidth
        //   pixelHeight = box.height * imageHeight
        // (box.origin.y is the bottom edge of the box in Vision's space, i.e.
        // its LOWEST y; flipping the whole box means that bottom edge becomes
        // the top-left-space's distance-from-bottom, so subtracting the
        // height too is what lands the top-left corner in the right place.)
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var pixelBoxes: [(rect: CGRect, confidence: Float)] = observations.map { obs in
            let box = obs.boundingBox
            let rect = CGRect(
                x: box.origin.x * width,
                y: (1 - box.origin.y - box.height) * height,
                width: box.width * width,
                height: box.height * height
            )
            return (rect, obs.confidence)
        }

        guard !pixelBoxes.isEmpty else { return [] }

        // Drop candidates whose area is wildly different from the median —
        // dice photographed together are similar sizes, so anything under
        // 1/3× or over 3× the median area is very likely a false positive
        // (a shadow, a table edge, a whole die tray).
        let areas = pixelBoxes.map { $0.rect.width * $0.rect.height }.sorted()
        let medianArea = areas[areas.count / 2]
        pixelBoxes = pixelBoxes.filter { candidate in
            let area = candidate.rect.width * candidate.rect.height
            return area >= medianArea / 3 && area <= medianArea * 3
        }

        // De-duplicate heavily overlapping boxes (the same die proposed
        // twice at slightly different quads): keep the higher-confidence box
        // of any pair with IoU > 0.5.
        pixelBoxes.sort { $0.confidence > $1.confidence }
        var kept: [(rect: CGRect, confidence: Float)] = []
        for candidate in pixelBoxes {
            let overlapsKept = kept.contains { iou($0.rect, candidate.rect) > 0.5 }
            if !overlapsKept { kept.append(candidate) }
        }

        // Cap at 6 by confidence, then order for a natural fill: top-to-
        // bottom, then left-to-right by centre (reading order).
        let capped = Array(kept.prefix(DiceTheme.slotCount))
        let ordered = capped
            .map { $0.rect }
            .sorted { a, b in
                if abs(a.midY - b.midY) > min(a.height, b.height) / 2 {
                    return a.midY < b.midY
                }
                return a.midX < b.midX
            }
        return ordered
    }

    /// Intersection-over-union of two rects, for overlap de-duplication.
    private static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }

    // MARK: Pixel sampling

    /// Normalizes a `UIImage` into an upright `CGImage` (orientation `.up`)
    /// by redrawing it once through `UIGraphicsImageRenderer`. `UIImage` can
    /// carry a `.cgImage` whose raw pixel data is stored rotated/mirrored
    /// per `imageOrientation` (e.g. photos straight from the camera are
    /// often `.right`); sampling that buffer directly would read the wrong
    /// pixels. Redrawing bakes the orientation in once, so every sample
    /// afterwards can use plain top-left-origin pixel math.
    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let upright = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return upright.cgImage
    }

    /// Renders a `side`×`side` region of `cgImage` centered at `point` into a
    /// tiny RGBA bitmap context and averages it. Using `CGContext` (rather
    /// than reading `CFData` pixel-by-pixel) lets CoreGraphics do the
    /// clamping/resampling at the edges of the image for free.
    private static func averageColor(in cgImage: CGImage, centeredAt point: CGPoint, side: CGFloat) -> RGBAColor? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapSize = 1 // downsample the whole region to a single pixel
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(
            data: &pixel,
            width: bitmapSize,
            height: bitmapSize,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the source region into the 1x1 context: CoreGraphics
        // downsamples/averages the region as part of the scale, which is
        // exactly the "average a small square" behaviour we want.
        //
        // `point` is in TOP-left-origin pixel space (this file's convention),
        // but `CGContext.draw` positions the image in the context's
        // BOTTOM-up coordinates — without a flip the sampled band is the
        // vertical MIRROR of the requested one (verified empirically: a
        // top-row die sampled the bottom-row die below it). Convert the
        // requested centre to CG space first: cgY = imageHeight − point.y.
        let sourceRect = CGRect(
            x: point.x - side / 2,
            y: CGFloat(cgImage.height) - point.y - side / 2,
            width: side,
            height: side
        )
        context.interpolationQuality = .medium
        context.draw(
            cgImage,
            in: CGRect(
                x: -sourceRect.minX * (CGFloat(bitmapSize) / side),
                y: -sourceRect.minY * (CGFloat(bitmapSize) / side),
                width: CGFloat(cgImage.width) * (CGFloat(bitmapSize) / side),
                height: CGFloat(cgImage.height) * (CGFloat(bitmapSize) / side)
            )
        )

        let alpha = Double(pixel[3])
        guard alpha > 0 else { return RGBAColor(red: 0, green: 0, blue: 0, alpha: 1) }
        // Un-premultiply so the stored colour is the true sampled RGB.
        return RGBAColor(
            red: Double(pixel[0]) / alpha,
            green: Double(pixel[1]) / alpha,
            blue: Double(pixel[2]) / alpha,
            alpha: 1
        )
    }
}
