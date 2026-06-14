//
//  CardView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct CardView: View {
    // MARK: - PROPERTIES
    @Environment(AuthViewModel.self) var viewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(QuizViewModel.self) var quizViewModel
    
    var body: some View {
        NavigationStack {
            // MARK: - HEADER
            VStack {
                if let user = viewModel.currentUser {
                    Text("Hello, \(user.fullname)!")
                        .greetingStyle()
                }
            }
            .padding(.leading, 15)
            .padding(.top, 20)
            
            Spacer()
            
            // MARK: - MAIN CONTENT
            VStack(alignment: .leading) {
                Text("Quick Math Quiz")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .padding(.bottom, 10)
                
                NavigationLink {
                    SubjectGridView(navigationSource: .cardView)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Image(systemName: "cross.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(colorScheme == .dark ? Color.pink : Color.cyan)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                }
                .buttonStyle(.plain) // Add plain style to prevent macOS highlighting oddities on pure images
                .padding(.top, 20)
            }
                
            // MARK: - FOOTER
            Spacer()
        
        } //: NAVIGATION STACK
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    } //: BODY
}

#Preview {
    CardView()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
