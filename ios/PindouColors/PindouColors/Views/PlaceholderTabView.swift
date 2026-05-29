import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text(title)
                    .font(.title.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        }
    }
}
