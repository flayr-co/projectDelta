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
                        SubjectGridView()
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
                    VStack(spacing: 20) {
                        if !quizEnded {
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
                                    .padding(.trailing, 25)
                            }
                            .onChange(of: selectedQuestionIndex) { newIndex in
                                currentQuestionIndex = newIndex
                            }
                            
                            // Display Current Question
                            Text("Question \(currentQuestionIndex + 1) of \(quizViewModel.questions.count)")
                                .font(.subheadline)
                            
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
                        let currentQuestion = quizViewModel.questions[currentQuestionIndex]
                        let answeredCorrectly = userAnswer == currentQuestion.correctOptionIndex

                        // Update score and user points
                        if answeredCorrectly {
                            score += 1
                            viewModel.currentUser?.points += 10
                        } else {
                            viewModel.currentUser?.points -= 5
                        }

                        // Check if we have the current subject information
                        if let currentSubject = quizViewModel.currentSubject {
                            // Handle the question answered logic
                            Task {
                                await quizViewModel.handleQuestionAnswered(question: currentQuestion, subject: currentSubject, answeredCorrectly: answeredCorrectly)
                                
                                do {
                                    try await viewModel.updateUserPointsInFirestore(newPoints: viewModel.currentUser?.points ?? 0)
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
                        } else {
                            print("Error: Subject data is not available.")
                        }

                        // Navigate to the next question or end the quiz
                        if currentQuestionIndex < quizViewModel.questions.count - 1 {
                            currentQuestionIndex += 1
                        } else {
                            quizEnded = true
                            if let selectedSubjectDocId = quizViewModel.selectedSubjectDocId {
                                quizViewModel.updateUserProgressForSubject(
                                    userId: viewModel.currentUser?.id ?? "",
                                    subjectDocId: selectedSubjectDocId,
                                    answeredCorrectly: score > 0)
                            }
                            currentQuestionIndex = 0
                        }
                        userAnswer = nil
                    } label: {
                        HStack {
                            Text("Next")
                                .fontWeight(.bold)

                            Image(systemName: "arrow.right")
                                .resizable()
                                .frame(width: 15, height: 12)
                                .fontWeight(.heavy)
                        }
                        .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                    }
                    .padding() 
                } //: HSTACK WITH BUTTONS
            } //: BIG VSTACK
        } //: NAVIGATIONSTACK
        .onAppear {
            quizViewModel.fetchRandomTest(for: subject)
        }
        .navigationBarBackButtonHidden(true)
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    } //: BODY
} //: QUICKTESTVIEW

#Preview {
    QuickTestView(subject: "Arithmetic")
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
//        .preferredColorScheme(.dark)
}
