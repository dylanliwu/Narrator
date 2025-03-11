//
//  FrameView.swift
//  P3
//
//  Created by Dylan Li on 2025-03-03.
//

import SwiftUI

struct FrameView: View {
    var image: CGImage?
    private let label = Text("Frame")
    var body: some View {
        if let image = image {
            Image(image, scale: 1, orientation: .up, label: label)
        }
        else {
            Color(.black)
        }
    }
}

#Preview {
    FrameView()
}
