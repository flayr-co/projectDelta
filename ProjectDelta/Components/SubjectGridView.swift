//
//  SubjectGridView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

// SubjectGridView.swift
import SwiftUI
import Firebase

enum NavigationSource {
    case homeView
    case cardView
    case testView // Added this case
}

struct SubjectGridView: View {
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var navigationSource: NavigationSource
    
    var body: some View {
        NavigationStack {
            HStack {
                BackButtonView {
                    dismiss()
                }
                Spacer()
            }
            
            Text("Choose a Subject")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                ForEach(quizViewModel.subjects, id: \.self) { subject in
                    NavigationLink {
                        switch navigationSource {
                        case .homeView:
                            LessonView(subjectName: subject)
                                .environment(lessonVM)
                        case .testView:
                            TestView(subject: subject)
                                .environment(quizViewModel)
                        case .cardView:
                            QuickTestView(subject: subject)
                                .environment(quizViewModel)
                        }
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
            .navigationBarBackButtonHidden(true)
        }
        .task {
            do {
                quizViewModel.subjects = try await quizViewModel.fetchSubjectsFromFirestore()
            } catch {
                print("Error fetching subjects in SubjectGridView: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SubjectGridView(navigationSource: .homeView)
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
        .preferredColorScheme(.dark)
}
