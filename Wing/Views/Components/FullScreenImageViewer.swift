//
//  FullScreenImageViewer.swift
//  Wing
//
//  Created on 2026-02-16.
//

import SwiftUI

struct FullScreenImageViewer: View {
    let image: UIImage
    let dismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Image with gestures
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let delta = value.magnification / lastScale
                            lastScale = value.magnification
                            let newScale = scale * delta
                            scale = min(max(newScale, 1.0), 5.0)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            withAnimation {
                                if scale < 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                // Pan
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            } else {
                                // Drag to dismiss (vertical)
                                offset = value.translation
                            }
                        }
                        .onEnded { value in
                            if scale > 1.0 {
                                lastOffset = offset
                            } else {
                                if abs(value.translation.height) > 100 {
                                    dismiss()
                                } else {
                                    withAnimation {
                                        offset = .zero
                                    }
                                }
                            }
                        }
                )
                .onTapGesture {
                    // Toggle controls or dismiss?
                }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}

#Preview {
    FullScreenImageViewer(image: UIImage(systemName: "photo")!, dismiss: {})
}
