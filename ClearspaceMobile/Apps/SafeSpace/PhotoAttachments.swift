import PhotosUI
import SwiftUI
import UIKit

/// A photo picked from the library or captured with the camera, ready to upload.
struct PickedPhoto: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let thumbnail: UIImage

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

/// Wraps UIImagePickerController for camera capture — PhotosPicker doesn't
/// support the camera.
struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Converts a camera-captured UIImage into a PickedPhoto (JPEG, with thumbnail).
func pickedPhoto(from image: UIImage, index: Int, prefix: String) async -> PickedPhoto? {
    guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return nil }
    let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 132, height: 132)) ?? image
    return PickedPhoto(name: "\(prefix)-\(index).jpg", data: jpeg, thumbnail: thumbnail)
}
