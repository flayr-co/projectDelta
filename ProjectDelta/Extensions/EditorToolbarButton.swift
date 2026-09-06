//
//  EditorToolbarButton.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/5/26.
//


//
//  EditorToolbarButton.swift
//  ProjectDelta
//

import SwiftUI

#if os(iOS)
struct EditorToolbarButton: View {
    let display: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(display)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
#endif