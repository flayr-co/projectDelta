//
//  SubjectGridView.swift
//  ProjectDelta
//

import SwiftUI
import Firebase

enum NavigationSource {
    case homeView
    case cardView
    case testView
}

struct SubjectGridView: View {
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var navigationSource: NavigationSource
    
    let warmTan = Color(red: 0.96, green: 0.94, blue: 0.90)
    let emeraldAccent = Color(red: 0.18, green: 0.80, blue: 0.44)
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : warmTan)
                    .ignoresSafeArea()
                
                VStack {
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
                                            .fill(emeraldAccent.opacity(0.15))
                                            .frame(width: 120, height: 50)
                                    )
                                    .font(.headline)
                                    .foregroundColor(emeraldAccent)
                                    .padding(15)
                            }
                        }
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
