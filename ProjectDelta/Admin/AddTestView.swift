//
//  AddTestView.swift
//  ProjectDelta
//
//  Created for Seamless Test Generation & Editing Flow
//

import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
class TestBuilderViewModel {
    var subjectName: String = ""
    var lessonName: String = ""
    var testTitle: String = ""
    var generatedQuestions: [Question] = []
    
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
            self.generatedQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            self.showEditor = true
        } catch {
            print("Failed to load test questions: \(error.localizedDescription)")
        }
        isGenerating = false
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        
        // Simulating the LLM generation delay. Hook this up to your actual API if needed.
        try? await Task.sleep(for: .seconds(2))
        
        var newQuestions: [Question] = []
        for i in 1...10 {
            let question = Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["Option A", "Option B", "Option C", "Option D"],
                points: 10,
                questionText: "Recommended Question \(i) testing concepts in \(lessonName)",
                type: "multipleChoice",
                subject: subjectName,
                subtopic: lessonName,
                hint: "Review the standard properties of \(lessonName).",
                feedback: "Option A is correct based on foundational logic.",
                testId: ""
            )
            newQuestions.append(question)
        }
        
        self.generatedQuestions = newQuestions
        self.testTitle = "\(lessonName) Comprehensive Test"
        self.isGenerating = false
        self.showEditor = true
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        do {
            let batch = db.batch()
            let testId = existingTestId ?? UUID().uuidString
            
            let testRef = db.collection("Tests").document(testId)
            let testData: [String: Any] = [
                "id": testId,
                "subject": subjectName,
                "lesson": lessonName,
                "title": testTitle.isEmpty ? "\(lessonName) Test" : testTitle,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef, merge: true)
            
            for question in generatedQuestions {
                let docData: [String: Any] = [
                    "id": question.id ?? UUID().uuidString,
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
                
                // Write to hierarchical subcollection
                let subRef = testRef.collection("Questions").document(question.id ?? UUID().uuidString)
                batch.setData(docData, forDocument: subRef)
                
                // Write to flat collection to maintain legacy compatibility
                let flatRef = db.collection("questions").document(question.id ?? UUID().uuidString)
                batch.setData(docData, forDocument: flatRef)
            }
            
            try await batch.commit()
            self.existingTestId = testId
        } catch {
            print("Failed to save test: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

struct AddTestView: View {
    var subjectName: String
    var lessonName: String
    var existingTestId: String?
    
    @State private var viewModel = TestBuilderViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white).ignoresSafeArea()
            
            VStack(spacing: 20) {
                if !viewModel.showEditor {
                    setupGeneratorView
                } else {
                    editorView
                }
            }
        }
        .navigationTitle(viewModel.existingTestId != nil ? "Edit Test" : "Test Builder")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.initialize(subject: subjectName, lesson: lessonName, testId: existingTestId)
        }
    }
    
    private var setupGeneratorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu")
                .font(.system(size: 60))
                .foregroundColor(.cyan)
                .padding(.top, 40)
            
            Text("Intelligent Test Builder")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Subject")
                    .font(.headline)
                TextField("Subject", text: $viewModel.subjectName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Designated Lesson")
                    .font(.headline)
                TextField("e.g. Linear Equations", text: $viewModel.lessonName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                Task { await viewModel.generateRecommendedTest() }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.subjectName.isEmpty || viewModel.lessonName.isEmpty ? Color.gray : Color.cyan)
                        .frame(height: 55)
                    
                    if viewModel.isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Generate 10 Questions")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.subjectName.isEmpty || viewModel.lessonName.isEmpty || viewModel.isGenerating)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
    
    private var editorView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Title", text: $viewModel.testTitle)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
            
            List {
                ForEach($viewModel.generatedQuestions) { $question in
                    Section(header: Text("Question").font(.headline).foregroundColor(.cyan)) {
                        TextField("Question Text", text: $question.questionText, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...5)
                        
                        ForEach(0..<question.options.count, id: \.self) { index in
                            HStack {
                                Button(action: { question.correctOptionIndex = index }) {
                                    Image(systemName: question.correctOptionIndex == index ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(question.correctOptionIndex == index ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                TextField("Option \(index + 1)", text: Binding(
                                    get: { question.options[index] },
                                    set: { question.options[index] = $0 }
                                ))
                            }
                        }
                        
                        TextField("Hint", text: Binding(
                            get: { question.hint ?? "" },
                            set: { question.hint = $0 }
                        ))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        
                        TextField("Explanation/Feedback", text: Binding(
                            get: { question.feedback ?? "" },
                            set: { question.feedback = $0 }
                        ))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
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
