//
//  TestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI
import FirebaseFirestore

struct TestView: View {
    @State private var buttonTapped = false
    @State private var currentQuestionIndex = 0
    @State private var quizEnded: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    @State private var showUIControls: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var isHintExpanded: Bool = false
    
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var subject: String
    var subtopic: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !buttonTapped {
                        introView
                    } else {
                        quizViewFlow
                    }
                }
            }
            .task {
                await fetchUserProgress()
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    private var introView: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .padding(8)
                }
                Spacer()
            }
            .padding(.top, 8)

            Spacer()
            
            VStack(spacing: 12) {
                Text(subtopic ?? "General \(subject)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Take the quiz in the time given")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("5 Minutes")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom))
            .padding(.bottom, 30)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    buttonTapped.toggle()
                }
                quizViewModel.fetchSubtopicTest(for: subject, subtopic: subtopic)
            }) {
                ZStack {
                    LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom)
                        .frame(height: 50)
                        .cornerRadius(10)
                    Text("Start Now")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            Spacer()
        }
    }

    @ViewBuilder
    private var quizViewFlow: some View {
        VStack(spacing: 0) {
            if showUIControls { headerView }

            if quizViewModel.isGeneratingQuiz {
                Spacer()
                ProgressView("Fetching test data...")
                Spacer()
            } else if quizEnded {
                quizEndView
            } else if !quizViewModel.questions.isEmpty {
                if showUIControls { questionSelector }
                
                TabView(selection: $currentQuestionIndex) {
                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                        questionContentPage(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentQuestionIndex) { _, newValue in
                    if selectedQuestionIndex != newValue {
                        selectedQuestionIndex = newValue
                    }
                }
            } else {
                Spacer()
                Text("No questions available for \(subject).")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .overlay(alignment: .bottom) {
            if !quizEnded && !quizViewModel.isGeneratingQuiz && !quizViewModel.questions.isEmpty && showUIControls {
                footerView
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text(subtopic ?? subject)
                .font(.headline).bold()
            Spacer()
        }.padding()
    }

    private var questionSelector: some View {
        HStack {
            Menu {
                Picker("Question", selection: $selectedQuestionIndex) {
                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                        Text("Question \(index + 1)").tag(index)
                    }
                }
            } label: {
                Label("Question \(currentQuestionIndex + 1)", systemImage: "chevron.down")
                    .foregroundColor(.cyan)
            }
            .onChange(of: selectedQuestionIndex) { _, newValue in
                withAnimation { currentQuestionIndex = newValue }
            }
            Spacer()
        }.padding(.horizontal)
    }

    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            if index < quizViewModel.questions.count {
                let question = quizViewModel.questions[index]
                let qId = question.id ?? UUID().uuidString
                
                VStack(alignment: .leading, spacing: 24) {
                    Text(question.questionText)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if let hint = question.hint, !hint.isEmpty {
                        DisclosureGroup("Hint", isExpanded: $isHintExpanded) {
                            Text(hint)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .tint(.cyan)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, optionText in
                            let isSelected = quizViewModel.userAnswers[qId] == optionIndex
                            
                            Button(action: {
                                quizViewModel.selectAnswer(for: qId, optionIndex: optionIndex)
                            }) {
                                HStack {
                                    Text(optionText)
                                        .font(.body)
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    } else {
                                        Circle()
                                            .stroke(Color.secondary, lineWidth: 1)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .padding()
                                .background(isSelected ? Color.cyan : Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var footerView: some View {
        HStack {
            if currentQuestionIndex > 0 {
                Button("Previous") {
                    withAnimation { currentQuestionIndex -= 1 }
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }
            
            Spacer()
            
            if currentQuestionIndex < quizViewModel.questions.count - 1 {
                Button("Next") {
                    withAnimation { currentQuestionIndex += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            } else {
                Button("Submit") {
                    isSubmitting = true
                    Task {
                        let dynamicSubtopic = subtopic ?? "All"
                        await quizViewModel.finishQuiz(subjectId: subject, subtopic: dynamicSubtopic)
                        quizEnded = true
                        isSubmitting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSubmitting)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }

    private var quizEndView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Quiz Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let snapshot = quizViewModel.currentSnapshot {
                Text("Score: \(snapshot.score) / \(snapshot.totalQuestions)")
                    .font(.title)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(snapshot.questionResults) { result in
                            HStack {
                                Text(result.questionText)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.isCorrect ? .green : .red)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .padding(.bottom, 30)
        }
    }
    
    private func fetchUserProgress() async {
        guard let userId = viewModel.currentUser?.id, !userId.isEmpty else { return }
        let db = Firestore.firestore()
        
        do {
            let document = try await db.collection("UserProgress").document(userId).getDocument()
            if let progress = try? document.data(as: UserProgress.self) {
                quizViewModel.userProgress = progress
            } else {
                print("User progress document exists but could not be decoded.")
            }
        } catch {
            print("Failed to fetch user progress: \(error.localizedDescription)")
        }
    }
}
