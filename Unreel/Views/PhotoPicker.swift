import PhotosUI
import SwiftUI

/// The system photo picker (no photo-library permission needed). Returns the
/// chosen photo as a JPEG, since Instagram's upload inputs take JPEG only.
struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (Data?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        // Photos only: Instagram's mobile site posts videos as Reels.
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data?) -> Void
        init(onPick: @escaping (Data?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                onPick(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onPick] object, _ in
                let data = (object as? UIImage).flatMap { Self.jpeg($0) }
                DispatchQueue.main.async { onPick(data) }
            }
        }

        /// Instagram resizes to 1080 px anyway; cap the long side to keep the hand-off small.
        static func jpeg(_ image: UIImage, maxSide: CGFloat = 2048) -> Data? {
            let size = image.size
            let scale = min(1, maxSide / max(size.width, size.height))
            let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
            return resized.jpegData(compressionQuality: 0.9)
        }
    }
}
