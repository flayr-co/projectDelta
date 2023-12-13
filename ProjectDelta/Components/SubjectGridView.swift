//
//  SubjectGridView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

// SubjectGridView.swift
import SwiftUI
import Firebase

struct SubjectGridView: View {
    @EnvironmentObject var quizViewModel: QuizViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            // MARK: - HEADER
            HStack {
                NavigationLink {
                    CardView()
                        .navigationBarBackButtonHidden(true)
                } label: {
                    BackButtonView()
                }
                
                Spacer()
            }
            
            // MARK: - MAIN CONTENT
            Text("Choose a Subject")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                ForEach(quizViewModel.subjects, id: \.self) { subject in
                    NavigationLink {
                        QuickTestView(subject: subject)
                            .environmentObject(quizViewModel)
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        Text(subject)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 120, height: 50)
                            )
                            .font(.headline)
                            .padding(15)
                    }
                }
            }
        } //: NAVIGATIONSTACK
    } //: BODY
}

#Preview {
    SubjectGridView()
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
        .preferredColorScheme(.dark)
}
