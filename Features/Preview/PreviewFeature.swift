import SwiftUI
import UIKit

struct PreviewFeatureView: View {
    let imageData: Data?
    let byteCount: Int

    var body: some View {
        Group {
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ContentUnavailableView(
                    "No Preview Frame",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Connect to a ColorBox and refresh the preview to pull the current frame.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if byteCount > 0 {
                Text("\(byteCount) B")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(12)
            }
        }
    }
}
