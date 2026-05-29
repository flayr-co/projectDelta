//
//  AddTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

@MainActor
@Observable
class TestBuilderViewModel {
    var subjectName: String = ""
    var lessonName: String = ""
    var testTitle: String = ""
    var generatedQuestions: [QuestionWrapper] = []
    
    var isGenerating: Bool = false
    var isSaving: Bool = false
    var showEditor: Bool = false
    var existingTestId: String? = nil
    
    private let db = Firestore.firestore()
    
    func initialize(subject: String, lesson: String, testId: String?) async {
        self.subjectName = subject
        self.lessonName = lesson
        self.existingTestId = testId
        
        if let tId = testId {
            await loadExistingTest(testId: tId)
        }
    }
    
    private func loadExistingTest(testId: String) async {
        isGenerating = true
        do {
            let snapshot = try await db.collection("Tests").document(testId).collection("Questions").getDocuments()
            let rawQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            self.generatedQuestions = rawQuestions.map { QuestionWrapper(question: $0) }
            self.showEditor = true
        } catch {
            print("Failed to load test questions: \(error.localizedDescription)")
        }
        isGenerating = false
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        self.generatedQuestions = (1...10).map { _ in
            QuestionWrapper(question: Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "",
                type: "multiple_choice",
                subject: subjectName,
                subtopic: lessonName,
                hint: "",
                feedback: "",
                testId: ""
            ))
        }
        
        showEditor = true
        isGenerating = false
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        
        // let finalDataToSave = generatedQuestions.map { $0.question }
        // Save logic to Firebase would go here
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isSaving = false
    }
}

struct AddTestView: View {
    let subjectName: String
    let lessonName: String
    var existingTest: Test? = nil
    
    @State private var viewModel = TestBuilderViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showEditor {
                editorContent
            } else {
                generatorContent
            }
        }
        .navigationTitle(existingTest != nil ? "Edit Test" : "New Test")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.initialize(subject: subjectName, lesson: lessonName, testId: existingTest?.id)
            if existingTest != nil {
                viewModel.testTitle = existingTest?.subject ?? "Untitled Test"
            }
        }
    }
    
    @ViewBuilder
    private var generatorContent: some View {
        VStack(spacing: 20) {
            Text("Create Test for \(subjectName)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Lesson: \(lessonName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                Task {
                    await viewModel.generateRecommendedTest()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.teal)
                        .frame(height: 55)
                    
                    if viewModel.isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Generate Questions")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isGenerating)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Test Details")) {
                    TextField("Test Title", text: $viewModel.testTitle)
                        .font(.headline)
                }
                
                ForEach($viewModel.generatedQuestions) { $wrapper in
                    AdminQuestionEditorCell(
                        question: $wrapper.question,
                        index: viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) ?? 0,
                        onDelete: {
                            withAnimation {
                                viewModel.generatedQuestions.removeAll(where: { $0.id == wrapper.id })
                            }
                        }
                    )
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.generatedQuestions.append(QuestionWrapper(question: Question(
                            id: UUID().uuidString,
                            correctOptionIndex: 0,
                            options: ["", "", "", ""],
                            points: 10,
                            questionText: "",
                            type: "multiple_choice",
                            subject: viewModel.subjectName,
                            subtopic: viewModel.lessonName,
                            hint: "",
                            feedback: "",
                            testId: viewModel.existingTestId
                        )))
                    }
                }) {
                    Label("Add Another Question", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            
            Button(action: {
                Task {
                    await viewModel.saveTestToDatabase()
                    dismiss()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green)
                        .frame(height: 55)
                    
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Test to Database")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
    }
}
