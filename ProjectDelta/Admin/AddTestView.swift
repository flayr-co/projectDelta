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
    var generatedQuestions: [EditableQuestion] = []
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
            self.generatedQuestions = rawQuestions.map { EditableQuestion(question: $0) }
            self.showEditor = true
        } catch { print("Error: \(error)") }
        isGenerating = false
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        try? await Task.sleep(for: .seconds(0.3))
        
        let generatedWrappers = await QuestionGeneratorEngine.shared.generateQuestions(
            subject: subject?.name ?? "",
            subtopic: lessonName,
            count: questionCount,
            testId: existingTestId
        )
        
        self.generatedQuestions = generatedWrappers.map { EditableQuestion(question: $0.question) }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showEditor = true
            isGenerating = false
        }
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
    let emeraldAccent = Color(red: 0.15, green: 0.80, blue: 0.50)

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
                    
                    Button("Deploy Assessment") {
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
            Image(systemName: "bolt.badge.automatic.fill")
                .font(.system(size: 64))
                .foregroundStyle(emeraldAccent.gradient)
                .shadow(color: emeraldAccent.opacity(0.4), radius: 20, y: 10)
                .padding(.bottom, 16)
            
            Text("Assessment Generator")
                .font(.system(size: 28, weight: .black, design: .rounded))
            
            Text("Intelligently scaffold a 10-question assessment based on \(lessonName).")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(spacing: 16) {
                Button(action: { Task { await viewModel.generateRecommendedTest() } }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(emeraldAccent.gradient)
                            .frame(height: 64)
                            .shadow(color: emeraldAccent.opacity(0.4), radius: 15, y: 8)
                        
                        if viewModel.isGenerating {
                            ProgressView().tint(.white).scaleEffect(1.2)
                        } else {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Generate Recommended Questions")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        }
                    }
                }
                .disabled(viewModel.isGenerating)
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.generatedQuestions = []
                        viewModel.showEditor = true
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(emeraldAccent, lineWidth: 2)
                            .background(Color.platformSystemBackground.cornerRadius(20))
                            .frame(height: 64)
                        
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("Build Manually with Blocks")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(emeraldAccent)
                    }
                }
                .disabled(viewModel.isGenerating)
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var editorContent: some View {
        @Bindable var bindableVM = viewModel
        
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 24) {
                // Metadata Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assessment Configuration")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    
                    TextField("Assessment Title...", text: $bindableVM.testTitle)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .padding(20)
                        .background(Color.platformSystemBackground)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
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
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
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
            .frame(maxWidth: 800)
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .scrollDismissesKeyboard(.interactively)
#if os(macOS)
        .safeAreaPadding(.top, 56)
#endif
        
#if os(iOS)
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                Task { await viewModel.saveTestToDatabase(); dismiss() }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(emeraldAccent.gradient)
                        .frame(height: 60)
                        .shadow(color: emeraldAccent.opacity(0.3), radius: 10, y: 5)
                    
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Deploy Assessment")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
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
    let emeraldAccent = Color(red: 0.15, green: 0.80, blue: 0.50)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    Text("\(index + 1)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(isExpanded ? emeraldAccent : .secondary.opacity(0.4))
                        .frame(width: 32, alignment: .leading)
                    
                    Text(isExpanded ? "Editing Question" : "Question \(index + 1)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isExpanded ? emeraldAccent : .primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(isExpanded ? emeraldAccent : .secondary.opacity(0.3))
                    
                    Divider().frame(height: 24).padding(.horizontal, 4)
                    
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red.opacity(0.9))
                            .font(.system(size: 18, weight: .bold))
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(isExpanded ? emeraldAccent.opacity(0.08) : Color.clear)
            }
            .buttonStyle(.plain)
            
            // Editor Body
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 28) {
                    UniversalBlockEditorView(blocks: $blocks)
                        .onChange(of: blocks) { _, newBlocks in
                            editableQuestion.question.updateWith(blocks: newBlocks)
                        }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Multiple Choice Parameters")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { i in
                                HStack(spacing: 16) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            editableQuestion.question.correctOptionIndex = i
                                        }
                                    }) {
                                        Image(systemName: editableQuestion.question.correctOptionIndex == i ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(editableQuestion.question.correctOptionIndex == i ? emeraldAccent : .gray.opacity(0.4))
                                            .font(.system(size: 24))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    TextField("Option \(i + 1)", text: Binding(
                                        get: { editableQuestion.question.options.indices.contains(i) ? editableQuestion.question.options[i] : "" },
                                        set: { if editableQuestion.question.options.indices.contains(i) { editableQuestion.question.options[i] = $0 } }
                                    ))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .padding(16)
                                    .background(Color.platformSecondarySystemBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(editableQuestion.question.correctOptionIndex == i ? emeraldAccent : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Feedback & Diagnostics")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        TextField("Optional Hint/Feedback...", text: Binding(
                            get: { editableQuestion.question.hint ?? "" },
                            set: { editableQuestion.question.hint = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(2...4)
                        .padding(16)
                        .background(Color.yellow.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(24)
            }
        }
        .background(Color.platformSystemBackground)
        .cornerRadius(24)
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.03), radius: isExpanded ? 20 : 8, y: isExpanded ? 10 : 4)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isExpanded ? emeraldAccent.opacity(0.4) : Color.primary.opacity(0.05), lineWidth: isExpanded ? 2 : 1))
        .onAppear {
            blocks = editableQuestion.question.parsedBlocks
            if blocks.isEmpty { isExpanded = true }
        }
    }
}
