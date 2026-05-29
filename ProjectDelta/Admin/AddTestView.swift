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
    
    var questionCount: Int = 10
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
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? subjectName
            
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").document(testId).collection("Questions").getDocuments()
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
        
        try? await Task.sleep(for: .seconds(1.5))
        
        self.generatedQuestions = (0..<questionCount).map { _ in
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
        
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? subjectName
            
            let batch = db.batch()
            
            let testId = existingTestId ?? UUID().uuidString
            let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
            
            let testData: [String: Any] = [
                "questionAmount": generatedQuestions.count,
                "subject": subjectName,
                "subtopic": lessonName,
                "testIdentifier": Int.random(in: 1000...9999),
                "timeLimit": 60,
                "title": testTitle.isEmpty ? "\(lessonName) Test" : testTitle,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef)
            
            for wrapper in generatedQuestions {
                let question = wrapper.question
                let qId = question.id ?? UUID().uuidString
                
                let docData: [String: Any] = [
                    "correctOptionIndex": question.correctOptionIndex,
                    "options": question.options,
                    "points": question.points,
                    "questionText": question.questionText,
                    "type": question.type,
                    "subject": subjectName,
                    "subtopic": lessonName,
                    "hint": question.hint ?? "",
                    "feedback": question.feedback ?? "",
                    "testId": testId
                ]
                
                let subRef = testRef.collection("Questions").document(qId)
                batch.setData(docData, forDocument: subRef)
                
                let flatRef = db.collection("questions").document(qId)
                batch.setData(docData, forDocument: flatRef)
            }
            
            try await batch.commit()
        } catch {
            print("Failed to save test: \(error.localizedDescription)")
        }
        
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
            
            Stepper(value: $viewModel.questionCount, in: 1...50) {
                Text("Number of Questions: \(viewModel.questionCount)")
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
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
                
                ForEach(viewModel.generatedQuestions) { wrapper in
                    let safeBinding = Binding<Question>(
                        get: {
                            guard let index = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) else { return wrapper.question }
                            return viewModel.generatedQuestions[index].question
                        },
                        set: { newValue in
                            guard let index = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) else { return }
                            viewModel.generatedQuestions[index].question = newValue
                        }
                    )
                    
                    let displayIndex = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) ?? 0
                    
                    AdminQuestionEditorCell(
                        question: safeBinding,
                        index: displayIndex,
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
