//
//  AddTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

@Observable
class EditableQuestion: Identifiable {
    let id = UUID()
    var question: Question
    
    init(question: Question) {
        self.question = question
    }
}

@MainActor
@Observable
class TestBuilderViewModel {
    var subject: Subject?
    var lessonName: String = ""
    var testTitle: String = ""
    var questionCount: Int = 10
    var generatedQuestions: [EditableQuestion] = [] // Upgraded to Reference Type
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
            // Map to Observable Class
            self.generatedQuestions = rawQuestions.map { EditableQuestion(question: $0) }
            self.showEditor = true
        } catch { print("Error: \(error)") }
        isGenerating = false
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        try? await Task.sleep(for: .seconds(0.3)) // Brief UI yield
        
        let generatedWrappers = QuestionGeneratorEngine.shared.generateQuestions(
            subject: subject?.name ?? "",
            subtopic: lessonName,
            count: questionCount,
            testId: existingTestId
        )
        
        // Map to Observable Class
        self.generatedQuestions = generatedWrappers.map { EditableQuestion(question: $0.question) }
        
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
                var question = wrapper.question // Extract the struct for saving
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
        VStack(spacing: 16) {
            Button(action: { Task { await viewModel.generateRecommendedTest() } }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(emeraldAccent)
                        .frame(height: 55)
                    
                    if viewModel.isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Recommended Questions")
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isGenerating)
            
            Button(action: {
                withAnimation {
                    viewModel.generatedQuestions = []
                    viewModel.showEditor = true
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(emeraldAccent, lineWidth: 2)
                        .background(Color.platformSystemBackground.cornerRadius(14))
                        .frame(height: 55)
                    
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Build Manually with Blocks")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(emeraldAccent)
                }
            }
            .disabled(viewModel.isGenerating)
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var editorContent: some View {
        @Bindable var bindableVM = viewModel
        
        ScrollView {
            LazyVStack(spacing: 32) {
                // Metadata Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assessment Configuration")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("Assessment Title...", text: $bindableVM.testTitle)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .padding(20)
                        .background(Color.platformSystemBackground)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                }
                
                // Questions Array
                LazyVStack(spacing: 20) {
                    ForEach(bindableVM.generatedQuestions) { editableQuestion in
                        let index = viewModel.generatedQuestions.firstIndex(where: { $0.id == editableQuestion.id }) ?? 0
                        
                        AdminQuestionEditorCell(
                            editableQuestion: editableQuestion,
                            index: index,
                            onDelete: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.generatedQuestions.removeAll(where: { $0.id == editableQuestion.id })
                                }
                            }
                        )
                    }
                }
                
                // Add Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.generatedQuestions.append(EditableQuestion(question: Question(
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
                    .background(emeraldAccent.opacity(0.10))
                    .foregroundColor(emeraldAccent)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(emeraldAccent.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 120)
            }
            .frame(maxWidth: 800) // Constrains width for absolute readability on macOS
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity) // Centers the constrained column within the scroll view
        .scrollDismissesKeyboard(.interactively)
#if os(macOS)
        .safeAreaPadding(.top, 56) // Scientifically fixes the macOS title bar cutoff
#endif
        
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
    @Bindable var editableQuestion: EditableQuestion
    var index: Int
    var onDelete: () -> Void
    
    @State private var blocks: [QuestionBlockModel] = []
    @State private var isExpanded: Bool = false
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (Always visible)
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    Text("\(index + 1)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(isExpanded ? emeraldAccent : .secondary.opacity(0.5))
                        .frame(width: 28, alignment: .leading)
                    
                    Text(isExpanded ? "Editing Question" : "Question \(index + 1)")
                        .font(.headline)
                        .foregroundColor(isExpanded ? emeraldAccent : .primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(isExpanded ? emeraldAccent : .secondary.opacity(0.5))
                    
                    Divider().frame(height: 24).padding(.horizontal, 4)
                    
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(isExpanded ? emeraldAccent.opacity(0.05) : Color.clear)
            }
            .buttonStyle(.plain)
            
            // Editor Body (Collapsible)
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 24) {
                    UniversalBlockEditorView(blocks: $blocks)
                        .onChange(of: blocks) { _, newBlocks in
                            editableQuestion.question.updateWith(blocks: newBlocks)
                        }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Multiple Choice Parameters")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { i in
                                HStack {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            editableQuestion.question.correctOptionIndex = i
                                        }
                                    }) {
                                        Image(systemName: editableQuestion.question.correctOptionIndex == i ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(editableQuestion.question.correctOptionIndex == i ? emeraldAccent : .gray.opacity(0.3))
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    TextField("Option \(i + 1)", text: Binding(
                                        get: { editableQuestion.question.options.indices.contains(i) ? editableQuestion.question.options[i] : "" },
                                        set: { if editableQuestion.question.options.indices.contains(i) { editableQuestion.question.options[i] = $0 } }
                                    ))
                                    .padding(14)
                                    .background(Color.platformSecondarySystemBackground)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(editableQuestion.question.correctOptionIndex == i ? emeraldAccent : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Optional Hint/Feedback...", text: Binding(
                            get: { editableQuestion.question.hint ?? "" },
                            set: { editableQuestion.question.hint = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(20)
            }
        }
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.04), radius: isExpanded ? 16 : 8, y: isExpanded ? 8 : 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpanded ? emeraldAccent.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            blocks = editableQuestion.question.parsedBlocks
            // Auto-expand if the question is newly added (blank)
            if blocks.isEmpty { isExpanded = true }
        }
    }
}
