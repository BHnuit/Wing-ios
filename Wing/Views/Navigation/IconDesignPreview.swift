import SwiftUI

struct IconDesignPreview: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Icon Design Options")
                .font(.largeTitle.bold())
                .padding(.top)
            
            // Option A: Wing Theme
            VStack {
                Text("Option A: Wing Theme (Bird)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                    Image(systemName: "bird.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }
            
            // Option B: Creation/Chat
            VStack {
                Text("Option B: Creation (Text Bubble)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }
            
            // Option C: Sparkle (AI Magic)
            VStack {
                Text("Option C: Magic (Sparkles)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#Preview {
    IconDesignPreview()
}
