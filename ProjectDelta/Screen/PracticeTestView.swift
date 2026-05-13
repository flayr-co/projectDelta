//
//  PracticeTestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/22/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct PracticeTestView: View {
    // MARK: - PROPERTIES
    @Environment(AuthViewModel.self) var viewModel
    // Upgraded: Removed @ObservedObject. Simple 'var' works for Observation framework when passing models.
    var practiceTestViewModel: PracticeTestViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswers = [Int?](repeating: nil, count: 10)  // Assuming 10 questions for simplicity
    @State private var userAnswer: Int?
    @State private var score: Int = 0
    @State private var practiceTestEnded: Bool = false
    @State private var navigateToCardView: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    var lessonID: String
    var practiceTestID: String

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
                
                // Lesson Title
                if !practiceTestEnded && currentQuestionIndex < practiceTestViewModel.questions.count {
                    Text("Practice Test")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .padding(.bottom, 10)
                }
                
                Spacer()
                
                // MARK: - MAIN CONTENT
                ScrollView {
                    VStack(spacing: 5) {
                        if !practiceTestEnded {
                            HStack(spacing: 70) {
                                Menu {
                                    Picker("Select Question", selection: $selectedQuestionIndex) {
                                        ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                                            Text("Question \(index + 1)")
                                                .tag(index)
                                        }
                                    }
                                } label: {
                                    Label("Question \(currentQuestionIndex + 1)", systemImage: "chevron.down")
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                                }
                                .onChange(of: selectedQuestionIndex) { oldValue, newIndex in
                                    currentQuestionIndex = newIndex
                                }
                                
                                // Display Current Question
                                Text("Question \(currentQuestionIndex + 1) of \(practiceTestViewModel.questions.count)")
                                    .font(.subheadline)
                            }
                            
                            if currentQuestionIndex < practiceTestViewModel.questions.count {
                                Spacer()
                                
                                TabView(selection: $currentQuestionIndex) {
                                    ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                                        ScrollView {
                                            VStack(spacing: 12) {
                                                Text(practiceTestViewModel.questions[index].questionText)
                                                    .font(.title3)
                                                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                                    .multilineTextAlignment(.leading)
                                                    .lineLimit(nil)
                                                    .padding()
                                                    .fixedSize(horizontal: false, vertical: true)

                                                ForEach(Array(practiceTestViewModel.questions[index].options.enumerated()), id: \.offset) { optionIndex, option in
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
                            Text("You have completed the practice test!")
                                .font(.headline)
                                .padding()
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            
                            Text("Your score is \(score) out of \(practiceTestViewModel.questions.count)")
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            
                            Button {
                                currentQuestionIndex = 0
                                score = 0
                                practiceTestEnded = false
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
                        if currentQuestionIndex < practiceTestViewModel.questions.count - 1 {
                            currentQuestionIndex += 1
                        } else {
                            // This is the last question
                            if !practiceTestEnded {
                                practiceTestEnded = true
                                practiceTestViewModel.setCurrentQuestionDocId(for: currentQuestionIndex)
                                // Post-quiz update logic, where score is recalculated
                                postPracticeTestUpdate()
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentQuestionIndex < practiceTestViewModel.questions.count - 1 ? "Next" : "Finish")
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
        .task {
            // Fetch practice test questions first, which is needed for the current view.
            await practiceTestViewModel.fetchPracticeTest(for: lessonID, practiceTestID: practiceTestID)
        }
        .navigationBarBackButtonHidden(true)
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    } //: BODY
    
    private func postPracticeTestUpdate() {
        practiceTestEnded = true
        print("Practice test has ended. Points and progress will now be updated....\n")

        // Calculate score by iterating over all answers
        score = 0
        for (index, answer) in userAnswers.enumerated() {
            if let answer = answer, answer == practiceTestViewModel.questions[index].correctOptionIndex {
                score += 1
            }
        }
        
        Task {
            guard let userId = viewModel.currentUser?.id, !userId.isEmpty else {
                print("User ID is nil or empty")
                return
            }
            
            // Calculate the total points change based on the new score
            let totalPointsChange = score * 10 - (practiceTestViewModel.questions.count - score) * 5
            
            // Update total points
            await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)

            // Update today's points
            await viewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
            
            // Update the user progress in Firestore
            if let currentSubjectArea = practiceTestViewModel.currentSubject?.subjectArea {
                if let subjectAreaEnum = SubjectArea(rawValue: currentSubjectArea),
                   let currentQuestionDocId = practiceTestViewModel.currentQuestionDocId { // Safely unwrapped
                    do {
                        try await practiceTestViewModel.updateUserProgressForSubject(
                            userID: userId,
                            subjectArea: subjectAreaEnum,
                            answeredCorrectly: score == practiceTestViewModel.questions.count,
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
            
            // Reset the practice test state
            currentQuestionIndex = 0 // Reset for the next time practice test is taken
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
} //: PRACTICETESTVIEW

#Preview {
    PracticeTestView(practiceTestViewModel: PracticeTestViewModel(authViewModel: AuthViewModel()), lessonID: "GZRfB4pXbn6rbxTeLpDp", practiceTestID: "VYccqY1rjXETQOdMm4ap")
        .environment(AuthViewModel()) // Upgraded for previews
//        .preferredColorScheme(.dark)
}
