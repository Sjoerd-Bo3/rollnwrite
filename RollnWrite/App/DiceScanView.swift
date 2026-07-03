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
//  App layer only: this is a Settings feature (composition), so it lives
//  here, never in Core — `DiceTheme` itself is untouched.
//

import SwiftUI
import UIKit
import PhotosUI

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
/// chips (pre-filled with the CURRENT palette). Tapping the photo samples the
/// colour under the tap into the active slot and auto-advances; tapping a
/// chip re-selects that slot. Apply writes all six colours to
/// `DiceTheme.shared.palette` in one assignment; Cancel discards.
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
    /// back into image space.
    @State private var displayedImageFrame: CGRect = .zero

    private let slotLabels = ["Die 1", "Die 2", "Die 3", "Die 4", "Die 5", "Die 6"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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
                uprightImage = Self.normalizedCGImage(from: image)
            }
        }
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

    // MARK: Coordinate mapping (view space → image pixel space)

    /// The frame `.scaledToFit` gives the image inside a `size`-sized
    /// container: the image is scaled uniformly by
    /// `min(size.width / image.width, size.height / image.height)`, then
    /// centred — producing letterbox bars on whichever axis has slack. This
    /// mirrors that math so a tap point can be converted back to image space.
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

    /// Samples the colour under a tap (in the `GeometryReader`'s local view
    /// space), fills the active slot, and auto-advances to the next slot.
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

        // Average a small square region (~2% of the smaller image dimension,
        // clamped to a sane 15–25px range) so a single noisy pixel (a
        // highlight, a pip) doesn't skew the read.
        let smallerDimension = CGFloat(min(cgImage.width, cgImage.height))
        let regionSide = max(15, min(25, smallerDimension * 0.02))

        guard let averaged = Self.averageColor(
            in: cgImage,
            centeredAt: CGPoint(x: pixelX, y: pixelY),
            side: regionSide
        ) else { return }

        slots[activeSlot] = averaged
        activeSlot = (activeSlot + 1) % DiceTheme.slotCount
        UISelectionFeedbackGenerator().selectionChanged()
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
        let sourceRect = CGRect(
            x: point.x - side / 2,
            y: point.y - side / 2,
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
