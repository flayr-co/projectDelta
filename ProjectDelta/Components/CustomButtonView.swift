//
//  CustomButtonView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct CustomButtonView: View {
    var body: some View {
        ZStack {
          Circle()
                .fill(
                    LinearGradient(colors:
                                   [.cyan, .teal],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
            
           Image(systemName: "goforward.plus")
                .fontWeight(.black)
                .font(.system(size: 32))
                .foregroundColor(.white)
        } //: ZSTACK
        .frame(width: 56, height: 56)
    }
}

#Preview {
    CustomButtonView()
        .previewLayout(.sizeThatFits)
        .padding()
}

