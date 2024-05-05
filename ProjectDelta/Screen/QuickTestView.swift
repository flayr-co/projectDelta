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
    @State private var userAnswers = [Int?](repeating: nil, count: 10)  // Assuming 10 questions for simplicity
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
                        CardView()
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
                                
                                TabView(selection: $currentQuestionIndex) {
                                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                                        ScrollView {
                                            VStack(spacing: 12) {
                                                Text(quizViewModel.questions[index].questionText)
                                                    .font(.title3)
                                                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                                    .multilineTextAlignment(.leading)
                                                    .lineLimit(nil)
                                                    .padding()
                                                    .fixedSize(horizontal: false, vertical: true)

                                                ForEach(Array(quizViewModel.questions[index].options.enumerated()), id: \.offset) { optionIndex, option in
                                                    Button(action: {
                                                        userAnswers[index] = optionIndex
                                                    }) {
                                                        optionView(option: option, isSelected: userAnswers[index] == optionIndex)
                                                    }
                                                }
                                            }
                                            .padding(.bottom, 20)
                                        }
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .frame(minHeight: 550, maxHeight: .infinity)  // Give a minimum height to ensure content is shown
                                .edgesIgnoringSafeArea(.all)  // Extend to the screen edges if necessary
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
                    
                    // Update Button Actions to only navigate and save data
                    Button {
                        if currentQuestionIndex < quizViewModel.questions.count - 1 {
                            currentQuestionIndex += 1
                        } else {
                            // This is the last question
                            if !quizEnded {
                                quizEnded = true
                                quizViewModel.setCurrentQuestionDocId(for: currentQuestionIndex)
                                // Post-quiz update logic, where score is recalculated
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
                    }
                    .disabled(userAnswers[currentQuestionIndex] == nil)
                    .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
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

        // Calculate score by iterating over all answers
        score = 0
        for (index, answer) in userAnswers.enumerated() {
            if let answer = answer, answer == quizViewModel.questions[index].correctOptionIndex {
                score += 1
            }
        }
        
        Task {
            guard let userId = viewModel.currentUser?.id, !userId.isEmpty else {
                print("User ID is nil or empty")
                return
            }
            
            // Calculate the total points change based on the new score
            let totalPointsChange = score * 10 - (quizViewModel.questions.count - score) * 5
            
            // Update total points
            await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)

            // Update today's points
            await viewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
            
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

    func optionView(option: String, isSelected: Bool) -> some View {
        HStack {
            Text(option)
                .font(.body)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                .padding()
            Spacer()
        }
        .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal)
    }
} //: QUICKTESTVIEW

#Preview {
    QuickTestView(subject: "Pre-Algebra")
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
//        .preferredColorScheme(.dark)
}
