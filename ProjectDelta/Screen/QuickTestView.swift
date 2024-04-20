//
//  QuickTestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/17/23.
//

// QuickTestView
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct QuickTestView: View {
    // MARK: - PROPERTIES
    @EnvironmentObject var viewModel: AuthViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswer: Int?
    @State private var score: Int = 0
    @State private var quizEnded: Bool = false
    @State private var navigateToCardView: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    var subject: String
    
    var body: some View {
        // MARK: - HEADER
        NavigationStack {
            VStack {
                HStack {
                    NavigationLink {
                        SubjectGridView(navigationSource: .cardView)
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        CloseButtonView()
                    }
                    
                    Spacer()
                }
                
                // Subject Title
                if !quizEnded && currentQuestionIndex < quizViewModel.questions.count {
                    Text(subject)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .padding(.bottom, 10)
                }
                
                Spacer()
                
                // MARK: - MAIN CONTENT
                ScrollView {
                    VStack(spacing: 5) {
                        if !quizEnded {
                            HStack(spacing: 70) {
                                Menu {
                                    Picker("Select Question", selection: $selectedQuestionIndex) {
                                        ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                                            Text("Question \(index + 1)")
                                                .tag(index)
                                        }
                                    }
                                } label: {
                                    Label("Question \(currentQuestionIndex + 1)", systemImage: "chevron.down")
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                                }
                                .onChange(of: selectedQuestionIndex) { newIndex in
                                    currentQuestionIndex = newIndex
                                }
                                
                                // Display Current Question
                                Text("Question \(currentQuestionIndex + 1) of \(quizViewModel.questions.count)")
                                    .font(.subheadline)
                            }
                            
                            if currentQuestionIndex < quizViewModel.questions.count {
                                Spacer()
                                
                                VStack(spacing: 12) {
                                    Spacer()
                                    
                                    Text(quizViewModel.questions[currentQuestionIndex].questionText)
                                        .font(.title3)
                                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                        .multilineTextAlignment(.leading)
                                        .minimumScaleFactor(0.5)
                                        .padding()
                                    
                                    // Display the options
                                    ForEach(Array(quizViewModel.questions[currentQuestionIndex].options.enumerated()), id: \.offset) { index, option in
                                        Button(action: {
                                            userAnswer = index
                                        }) {
                                            HStack {
                                                Text(option)
                                                    .font(.body)
                                                    .foregroundColor(userAnswer == index ? .white : (colorScheme == .dark ? .white : .black))
                                                    .padding()
                                                Spacer()
                                            }
                                            .background(userAnswer == index ? Color.blue : Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    //                            TextField("Your answer", text: $userAnswer)
                                    //                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                    //                                .padding(.horizontal, 20)
                                    
                                }
                                .padding(.bottom, 50)
                            }
                        } else {
                            Text("You have completed the quiz!")
                                .font(.headline)
                                .padding()
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            
                            Text("Your score is \(score) out of \(quizViewModel.questions.count)")
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            
                            Button {
                                currentQuestionIndex = 0
                                score = 0
                                quizEnded = false
                            } label: {
                                Text("Retry?")
                                    .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                            }
                            .padding()
                            
                            NavigationLink {
                                CardView()
                                    .navigationBarBackButtonHidden(true)
                            } label: {
                                Text("Go Home?")
                                    .font(.subheadline)
                                    .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                            }
                        }
                        
                        Spacer()
                    } //: VSTACK
                } //: SCROLLVIEW
                Spacer()
                
                // MARK: - BOTTOM BUTTONS
                HStack(spacing: 60) {
                    Button {
                        if currentQuestionIndex > 0 {
                            currentQuestionIndex -= 1
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left")
                                .resizable()
                                .frame(width: 15, height: 12)
                                .fontWeight(.heavy)
                            
                            Text("Previous")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                        .foregroundStyle(Color(.white))
                    }
                    .disabled(currentQuestionIndex == 0) // Disable the button when on the first question
                    
                    Button {
                        if currentQuestionIndex < quizViewModel.questions.count - 1 {
                            // Check the answer for the current question before moving to the next one
                            if userAnswer == quizViewModel.questions[currentQuestionIndex].correctOptionIndex && !quizEnded {
                                score += 1
                                quizViewModel.setCurrentQuestionDocId(for: currentQuestionIndex) // (SHOULD I HAVE THIS CALL HERE AS WELL?
                            }
                            // Move to the next question
                            currentQuestionIndex += 1
                            // Reset the answer for the next question
                            userAnswer = nil
                        } else {
                            // This is the last question
                            if !quizEnded {
                                // Check the answer for the last question and end the quiz
                                if userAnswer == quizViewModel.questions[currentQuestionIndex].correctOptionIndex {
                                    score += 1
                                }
                                quizViewModel.setCurrentQuestionDocId(for: currentQuestionIndex) // ADDED THIS LINE
                                quizEnded = true

                                // Post-quiz update logic
                                postQuizUpdate()
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentQuestionIndex < quizViewModel.questions.count - 1 ? "Next" : "Finish")
                                .fontWeight(.bold)
                            
                            Image(systemName: "arrow.right")
                                .resizable()
                                .frame(width: 15, height: 12)
                                .fontWeight(.heavy)
                        }
                        .disabled(userAnswer == nil)
                        .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                    }
                    .padding()
                } //: HSTACK WITH BUTTONS
            } //: BIG VSTACK
        } //: NAVIGATIONSTACK
        .onAppear {
            // Fetch random test first, which is needed for the current view.
            quizViewModel.fetchRandomTest(for: subject)

            // Then, handle user progress.
            Task {
                guard let userId = viewModel.userSession?.uid else {
                    print("User ID is nil or empty")
                    return
                }

                // Fetch User's Progress first
                do {
                    let userProgress = try await quizViewModel.fetchUserProgress(forUserID: userId)
                    if let userProgress = userProgress {
                        // User progress exists
                        print("User progress fetched: \(userProgress)")
                        quizViewModel.userProgress = userProgress
                    } else {
                        // User progress does not exist, create it
                        print("No user progress exists for user ID: \(userId), creating new one.")
                        try await viewModel.createUserProgress(userId: userId)
                    }
                } catch {
                    // Handle the error more specifically if possible
                    print("Error fetching user progress: \(error.localizedDescription)")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    } //: BODY
    
    private func postQuizUpdate() {
        quizEnded = true
        print("Quiz has ended. Points and progress will now be updated....\n")
        
        // Ensure we have a valid user ID
        Task {
            guard let userId = viewModel.currentUser?.id, !userId.isEmpty else {
                print("User ID is nil or empty")
                return
            }
            
            // Calculate the total points change based on the score
            let totalPointsChange = score * 10 - (quizViewModel.questions.count - score) * 5

            // Assume updateUserPointsInFirestore now also updates the total points
            // alongside calling storeTodaysPoints internally or through another mechanism.
            do {
                try await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)
            } catch {
                print("Failed to update points: \(error.localizedDescription)")
            }
            
            // Update the user progress in Firestore
            if let currentSubjectArea = quizViewModel.currentSubject?.subjectArea {
                if let subjectAreaEnum = SubjectArea(rawValue: currentSubjectArea),
                   let currentQuestionDocId = quizViewModel.currentQuestionDocId { // Safely unwrapped
                    do {
                        try await quizViewModel.updateUserProgressForSubject(
                            userID: userId,
                            subjectArea: subjectAreaEnum,
                            answeredCorrectly: score == quizViewModel.questions.count,
                            questionDocumentID: currentQuestionDocId
                        )
                    } catch {
                        print("Failed to update user progress in Firestore: \(error.localizedDescription)")
                    }
                } else {
                    print("Subject area or current question document ID is not valid.")
                }
            } else {
                print("Subject area is not set.")
            }
            
            // Reset the quiz state
            currentQuestionIndex = 0 // Reset for the next time quiz is taken
        }
    }
} //: QUICKTESTVIEW

#Preview {
    QuickTestView(subject: "Arithmetic")
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
//        .preferredColorScheme(.dark)
}
