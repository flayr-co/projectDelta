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
    var subject: Subject?
    var lessonName: String = ""
    var testTitle: String = ""
    var questionCount: Int = 10
    var generatedQuestions: [QuestionWrapper] = []
    var isGenerating: Bool = false
    var isSaving: Bool = false
    var showEditor: Bool = false
    var existingTestId: String? = nil
    private let db = Firestore.firestore()
    
    func initialize(subject: Subject, lesson: String, testId: String?) async {
        self.subject = subject
        self.lessonName = lesson
        self.existingTestId = testId
        if let tId = testId { await loadExistingTest(testId: tId) }
    }
    
    private func loadExistingTest(testId: String) async {
        isGenerating = true
        guard let subjectId = subject?.id else { return }
        do {
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").document(testId).collection("Questions").getDocuments()
            let rawQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            self.generatedQuestions = rawQuestions.map { QuestionWrapper(question: $0) }
            self.showEditor = true
        } catch { print("Error: \(error)") }
        isGenerating = false
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        try? await Task.sleep(for: .seconds(0.8))
        self.generatedQuestions = (0..<questionCount).map { _ in
            QuestionWrapper(question: Question(id: UUID().uuidString, correctOptionIndex: 0, options: ["", "", "", ""], points: 10, questionText: "", type: "multiple_choice", subject: subject?.name ?? "", subtopic: lessonName, hint: "", feedback: "", testId: ""))
        }
        showEditor = true
        isGenerating = false
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        guard let subject = subject, let subjectId = subject.id else { isSaving = false; return }
        do {
            let batch = db.batch()
            let testId = existingTestId ?? UUID().uuidString
            let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
            
            let testData: [String: Any] = [
                "questionAmount": generatedQuestions.count,
                "subject": subject.name,
                "subtopic": lessonName,
                "testIdentifier": Int.random(in: 1000...9999),
                "timeLimit": 60,
                "title": testTitle.isEmpty ? "\(lessonName) Test" : testTitle,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef)
            
            let existingQuestionsSnap = try await testRef.collection("Questions").getDocuments()
            let existingQIds = Set(existingQuestionsSnap.documents.map { $0.documentID })
            let currentQIds = Set(generatedQuestions.compactMap { $0.question.id })
            
            for id in existingQIds.subtracting(currentQIds) {
                batch.deleteDocument(testRef.collection("Questions").document(id))
                batch.deleteDocument(db.collection("questions").document(id))
            }
            
            for wrapper in generatedQuestions {
                var question = wrapper.question
                let qId = question.id ?? UUID().uuidString
                question.id = qId
                let docData: [String: Any] = ["correctOptionIndex": question.correctOptionIndex, "options": question.options, "points": question.points, "questionText": question.questionText, "type": question.type, "subject": subject.name, "subtopic": lessonName, "hint": question.hint ?? "", "feedback": question.feedback ?? "", "testId": testId]
                batch.setData(docData, forDocument: testRef.collection("Questions").document(qId))
                batch.setData(docData, forDocument: db.collection("questions").document(qId))
            }
            try await batch.commit()
        } catch { print("Save failed: \(error)") }
        isSaving = false
    }
}

struct AddTestView: View {
    let subject: Subject
    let lessonName: String
    var existingTest: Test? = nil
    
    @State private var viewModel = TestBuilderViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)

    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            if viewModel.showEditor {
                editorContent
            } else {
                generatorContent
            }
        }
        .navigationTitle(existingTest != nil ? "Edit Assessment" : "Build Assessment")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            if viewModel.showEditor {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.borderless)
                    
                    Button("Deploy") {
                        Task { await viewModel.saveTestToDatabase(); dismiss() }
                    }
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .tint(emeraldAccent)
                    .disabled(viewModel.isSaving)
                }
            }
            #endif
        }
        .task {
            await viewModel.initialize(subject: subject, lesson: lessonName, testId: existingTest?.id)
            if existingTest != nil {
                viewModel.testTitle = existingTest?.title ?? existingTest?.subject ?? "Untitled Test"
            }
        }
    }
    
    @ViewBuilder
    private var generatorContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 60))
                .foregroundColor(emeraldAccent)
            
            Text("Assessment Generator")
                .font(.title)
                .fontWeight(.heavy)
            
            Text("Building structure for:\n**\(lessonName)**")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack {
                Text("Question Count: \(viewModel.questionCount)")
                    .font(.headline)
                Slider(value: Binding(get: { Double(viewModel.questionCount) }, set: { viewModel.questionCount = Int($0) }), in: 1...50, step: 1)
                    .tint(emeraldAccent)
            }
            .padding()
            .background(Color.platformSystemBackground)
            .cornerRadius(16)
            .padding(.horizontal, 30)
            
            Button(action: { Task { await viewModel.generateRecommendedTest() } }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(emeraldAccent)
                        .frame(height: 55)
                    
                    if viewModel.isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Initialize Canvas")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isGenerating)
            .padding(.horizontal, 30)
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.top, 60)
    }
    
    @ViewBuilder
    private var editorContent: some View {
        @Bindable var bindableVM = viewModel
        
        ScrollView {
            LazyVStack(spacing: 20) {
                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Configuration")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("Assessment Title...", text: $bindableVM.testTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.platformSystemBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Questions Array
                ForEach($bindableVM.generatedQuestions) { $wrapper in
                    let index = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) ?? 0
                    
                    AdminQuestionEditorCell(
                        question: $wrapper.question,
                        index: index,
                        onDelete: {
                            withAnimation { viewModel.generatedQuestions.removeAll(where: { $0.id == wrapper.id }) }
                        }
                    )
                }
                
                // Add Button
                Button(action: {
                    withAnimation {
                        viewModel.generatedQuestions.append(QuestionWrapper(question: Question(
                            id: UUID().uuidString, correctOptionIndex: 0, options: ["", "", "", ""], points: 10, questionText: "", type: "multiple_choice", subject: subject.name, subtopic: lessonName, hint: "", feedback: "", testId: viewModel.existingTestId
                        )))
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Manual Question")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(emeraldAccent.opacity(0.15))
                    .foregroundColor(emeraldAccent)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        #if os(iOS)
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                Task { await viewModel.saveTestToDatabase(); dismiss() }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(emeraldAccent)
                        .frame(height: 55)
                    
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Deploy Assessment")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(Color.platformSystemGroupedBackground.opacity(0.95))
        }
        #endif
    }
}

struct AdminQuestionEditorCell: View {
    @Binding var question: Question
    var index: Int
    var onDelete: () -> Void
    
    @State private var blocks: [QuestionBlockModel] = []
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Question \(index + 1)")
                    .font(.headline)
                    .foregroundColor(emeraldAccent)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            Divider()
            
            UniversalBlockEditorView(blocks: $blocks)
                .onChange(of: blocks) { _, newBlocks in
                    question.updateWith(blocks: newBlocks)
                }
            
            Divider()
            
            Text("Multiple Choice Parameters")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Button(action: { question.correctOptionIndex = i }) {
                            Image(systemName: question.correctOptionIndex == i ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(question.correctOptionIndex == i ? emeraldAccent : .gray.opacity(0.5))
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        
                        TextField("Option \(i + 1)", text: Binding(
                            get: { question.options.indices.contains(i) ? question.options[i] : "" },
                            set: { if question.options.indices.contains(i) { question.options[i] = $0 } }
                        ))
                        .padding(10)
                        .background(Color.platformSecondarySystemBackground)
                        .cornerRadius(8)
                    }
                }
            }
            
            TextField("Optional Hint/Feedback...", text: Binding(
                get: { question.hint ?? "" },
                set: { question.hint = $0.isEmpty ? nil : $0 }
            ))
            .padding(10)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .padding(.horizontal)
        .onAppear {
            blocks = question.parsedBlocks
        }
    }
}
