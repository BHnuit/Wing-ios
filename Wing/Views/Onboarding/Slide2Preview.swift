import SwiftUI

struct Slide2PreviewWrapper: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            SynthesisAnimationView()
        }
    }
}

#Preview("Slide 2 Redesign") {
    Slide2PreviewWrapper()
}
