//
//  TestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        // MARK: - PROPERTIES
        
        // MARK: - HEADER
        Section {
            VStack(spacing: 6) {
                
                Spacer()
                
                Text("Take the quiz in the time given")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("5 Minutes")
                    .font(.system(size: 20, weight: .semibold))
            } //: VSTACK
            .foregroundStyle(
                LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom)
            )
            .padding(.bottom, 30)
            
            VStack(spacing: 4) {
                Text("Remember...")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Practice makes perfect")
                    .font(.subheadline)
                    .fontWeight(.regular)
                
                Spacer()
            } //: VSTACK
            .multilineTextAlignment(.center)
            .padding(.top, 0)
            .frame(maxWidth: .infinity)
        } //: SECTION
        
        // MARK: - TEST CONTENT
        Section {
            Spacer()
            TestContent()
            Spacer()
        } //: SECTION
        .padding(.top, 2)
        
        // MARK: - FOOTER
        Section {
            HStack {
                Spacer()
                Text("Copyright ©. All rights reserved")
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}

#Preview {
    TestView()
}
