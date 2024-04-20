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
}

struct SubjectGridView: View {
    @EnvironmentObject var quizViewModel: QuizViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var navigationSource: NavigationSource
    
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
                        if navigationSource == .homeView {
                            LessonView(subjectName: subject, lessonVM: LessonViewModel(subjectName: subject))
                                .environmentObject(quizViewModel)
                        } else {
                            QuickTestView(subject: subject)
                                .environmentObject(quizViewModel)
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
        } //: NAVIGATIONSTACK
        .onAppear {
            Task {
                do {
                    quizViewModel.subjects = try await quizViewModel.fetchSubjectsFromFirestore()
                } catch {
                    print("Error fetching subjects in SubjectGridView: \(error.localizedDescription)")
                }
            }
        }
    } //: BODY
}

#Preview {
    SubjectGridView(navigationSource: .homeView)
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
        .preferredColorScheme(.dark)
}
