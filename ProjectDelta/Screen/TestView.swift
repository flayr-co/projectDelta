//
//  TestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct TestView: View {
    @State private var buttonTapped = false
    @State private var currentQuestionIndex = 0
    @State private var userAnswers = [Int?](repeating: nil, count: 10)
    @State private var score: Int = 0
    @State private var quizEnded: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    var subject: String

    var body: some View {
        ZStack {
            backgroundView
            mainContent
        }
        .edgesIgnoringSafeArea(.all) // Ensure the background fills the entire screen
        .task {
            await fetchUserProgress()
        }
        .navigationBarBackButtonHidden(true)
    }

    private var backgroundView: some View {
        (colorScheme == .dark ? Color.customDarkGray : Color.gray.opacity(0.2))
            .edgesIgnoringSafeArea(.all)
    }

    private var mainContent: some View {
        VStack {
            if !buttonTapped {
                introView
            } else {
                quizView
            }
        }
    }

    private var introView: some View {
        VStack {
            Spacer()
            VStack(spacing: 6) {
                Text("Take the quiz in the time given")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("5 Minutes")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(
                LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom)
            )
            .padding(.bottom, 30)
            VStack(spacing: 4) {
                Text("Remember...")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Practice makes perfect")
                    .font(.subheadline)
                    .fontWeight(.regular)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 30)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    buttonTapped.toggle()
                }
                quizViewModel.fetchRandomTest(for: subject)
            }) {
                startButton
            }
            .padding(.bottom, 30)
            Spacer()
        }
        .padding(.horizontal, 20) // Adjust padding to fit content better
    }

    private var startButton: some View {
        ZStack {
            if buttonTapped {
                Color.white
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .transition(.move(edge: .leading))
            } else {
                LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom)
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            Text("Start Now")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(buttonTapped ? .cyan : .white)
                .padding()
        }
    }

    private var quizView: some View {
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
                if !quizEnded && currentQuestionIndex < quizViewModel.questions.count {
                    Text(subject)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .padding(.bottom, 10)
                }
                ScrollView {
                    VStack(spacing: 20) { // Increased spacing for better layout
                        if !quizEnded {
                            questionSelector
                            questionView
                        } else {
                            quizEndView
                        }
                    }
                    .padding()
                }
                footerView
                    .padding(.bottom, 20) // Add padding to avoid overlap with the bottom edge
            }
            .frame(maxWidth: .infinity)
            .background(colorScheme == .dark ? Color.customDarkGray : Color.gray.opacity(0.2))
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }

    private var questionSelector: some View {
        HStack(spacing: 20) {
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
            .onChange(of: selectedQuestionIndex) { oldValue, newValue in
                currentQuestionIndex = newValue
            }
            Spacer()
            Text("Question \(currentQuestionIndex + 1) of \(quizViewModel.questions.count)")
                .font(.subheadline)
        }
        .padding(.horizontal, 20)
    }

    private var questionView: some View {
        if currentQuestionIndex < quizViewModel.questions.count {
            Spacer()
            return AnyView(TabView(selection: $currentQuestionIndex) {
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
            .frame(minHeight: 550, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all))
        }
        return AnyView(Spacer())
    }

    private var quizEndView: some View {
        VStack {
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
    }

    private var footerView: some View {
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
            }
            .disabled(currentQuestionIndex == 0)
            Button {
                if currentQuestionIndex < quizViewModel.questions.count - 1 {
                    currentQuestionIndex += 1
                } else {
                    if !quizEnded {
                        quizEnded = true
                        quizViewModel.setCurrentQuestionDocId(for: currentQuestionIndex)
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
        }
    }

    private func postQuizUpdate() {
        quizEnded = true
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
            let totalPointsChange = score * 10 - (quizViewModel.questions.count - score) * 5
            await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)
            await viewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
            if let currentSubjectArea = quizViewModel.currentSubject?.subjectArea {
                if let subjectAreaEnum = SubjectArea(rawValue: currentSubjectArea),
                   let currentQuestionDocId = quizViewModel.currentQuestionDocId {
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
                }
            }
            currentQuestionIndex = 0
        }
    }

    private func fetchUserProgress() async {
        guard let userId = viewModel.userSession?.uid else {
            print("User ID is nil or empty")
            return
        }
        do {
            let userProgress = try await viewModel.fetchUserProgress(forUserID: userId)
            if let userProgress = userProgress {
                quizViewModel.userProgress = userProgress
            } else {
                try await viewModel.createUserProgress(userId: userId)
            }
        } catch {
            print("Error fetching user progress: \(error.localizedDescription)")
        }
    }

    private func optionView(option: String, isSelected: Bool) -> some View {
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
}

#Preview {
    TestView(subject: "Pre-Algebra")
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
