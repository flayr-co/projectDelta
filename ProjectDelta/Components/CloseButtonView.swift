//
//  CloseButtonView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

import SwiftUI

struct CloseButtonView: View {
    var body: some View {
        Image(systemName: "xmark.circle.fill")
            .imageScale(.small)
            .font(.title)
            .padding(.leading, 20)
            .foregroundColor(Color.red)
    }
}

struct BackButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: "arrow.left.circle.fill")
                .imageScale(.small)
                .font(.title)
                .padding(.leading, 20)
                .foregroundColor(Color.red)
        }
    }
}

#Preview {
    BackButtonView(action: {})
}

