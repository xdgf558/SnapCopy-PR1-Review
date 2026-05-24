import SwiftUI

struct RatingView: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= selectedRating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(value <= selectedRating ? .yellow : .secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value)分")
            }
        }
    }

    private var selectedRating: Int {
        rating ?? 0
    }
}
