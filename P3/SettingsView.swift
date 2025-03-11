//
//  SettingsView.swift
//  P3
//
//  Created by Dylan Li on 2025-03-10.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.system(size: 54))
                .fontWeight(.semibold)
            GeometryReader { geometry in
                VStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue)
                        .padding(.horizontal, geometry.size.width * (1/12))
                        .padding(.bottom, 20)
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue)
                        .padding(.horizontal, geometry.size.width * (1/12))
                }
            }
        }
        .padding(.top, 25)
    }
}

#Preview {
    SettingsView()
}
