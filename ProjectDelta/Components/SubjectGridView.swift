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
    @EnvironmentObject var lessonVM: LessonViewModel

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode  // To programmatically dismiss the view
    var navigationSource: NavigationSource
    
    var body: some View {
        NavigationStack {
            // MARK: - HEADER
            HStack {
                if navigationSource == .cardView {
                    // If navigated from CardView, show a back button to CardView
                    Button(action: {
                        // Custom action to navigate back to CardView
                        // If using a NavigationStack, you could pop back
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        BackButtonView()
                    }
                } else {
                    // If navigated from HomeView, show a back button to HomeView
                    Button(action: {
                        // Custom action to navigate back to HomeView
                        // If using a NavigationStack, you could pop back
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        BackButtonView()
                    }
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
                            LessonView(subjectName: subject)
                                .environmentObject(lessonVM)
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
            .navigationBarBackButtonHidden(true)
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
