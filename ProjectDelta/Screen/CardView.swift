//
//  CardView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct CardView: View {
    // MARK: - PROPERTIES
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var quizViewModel: QuizViewModel
    
    var body: some View {
        NavigationStack {
            // MARK: - HEADER
//            HStack {
//                NavigationLink {
//                    ProfileView()
//                } label: {
//                    BackButtonView()
//                }
//                Text("Go back")
//                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
//                
//                Spacer()
//            }
            
            VStack {
                if let user = viewModel.currentUser {
                    Text("Hello, \(user.fullname)!")
                        .greetingStyle()
                }
//                else {
//                    Text("Hello!")
//                        .greetingStyle()
//                }
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
                    SubjectGridView()
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Image(systemName: "cross.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(colorScheme == .dark ? Color.pink : Color.cyan)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                }
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
        .environmentObject(AuthViewModel())
}
