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
    var generatedQuestions: [EditableQuestion] = []
    var isSaving: Bool = false
    var showEditor: Bool = false
    var existingTestId: String? = nil
    private let db = Firestore.firestore()
    
    func initialize(subject: Subject, lesson: String, testId: String?) async {
        self.subject = subject
        self.lessonName = lesson
        self.existingTestId = testId
        
        if let tId = testId {
            await loadExistingTest(testId: tId)
        } else {
            initializeManualBuilder()
        }
    }
    
    private func loadExistingTest(testId: String) async {
        guard let subjectId = subject?.id else { return }
        do {
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").document(testId).collection("Questions").getDocuments()
            let rawQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            self.generatedQuestions = rawQuestions.sorted(by: { ($0.id ?? "") < ($1.id ?? "") }).map { EditableQuestion(question: $0) }
            self.showEditor = true
        } catch {
            print("Error loading test: \(error)")
        }
    }
    
    func initializeManualBuilder() {
        if generatedQuestions.isEmpty {
            generatedQuestions.append(EditableQuestion(question: Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "",
                type: "multiple_choice",
                subject: subject?.name ?? "",
                subtopic: lessonName,
                hint: "",
                feedback: "",
                testId: existingTestId
            )))
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showEditor = true }
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
            batch.setData(testData, forDocument: testRef, merge: true)
            
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
                let docData: [String: Any] = [
                    "correctOptionIndex": question.correctOptionIndex,
                    "options": question.options,
                    "points": question.points,
                    "questionText": question.questionText,
                    "type": question.type,
                    "subject": subject.name,
                    "subtopic": lessonName,
                    "hint": question.hint ?? "",
                    "feedback": question.feedback ?? "",
                    "testId": testId
                ]
                batch.setData(docData, forDocument: testRef.collection("Questions").document(qId))
                batch.setData(docData, forDocument: db.collection("questions").document(qId))
            }
            try await batch.commit()
        } catch {
            print("Save failed: \(error)")
        }
        isSaving = false
    }
    
    // MARK: - Bulk Importer Logic
    func processBulkQuestionImport(text: String) {
        var remaining = text
        var newWrappers: [EditableQuestion] = []

        while let qStart = remaining.range(of: "[QUESTION]"),
              let qEnd = remaining.range(of: "[/QUESTION]") {
            
            let qBlock = String(remaining[qStart.upperBound..<qEnd.lowerBound])
            remaining = String(remaining[qEnd.upperBound...])
            
            var question = Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "",
                type: "multiple_choice",
                subject: self.subject?.name ?? "",
                subtopic: self.lessonName,
                hint: nil,
                feedback: nil,
                testId: self.existingTestId
            )
            
            // 1. Parse Block Content
            if let cStart = qBlock.range(of: "[CONTENT]"), let cEnd = qBlock.range(of: "[/CONTENT]") {
                let contentRaw = String(qBlock[cStart.upperBound..<cEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                var blocks: [QuestionBlockModel] = []
                var remainingContent = contentRaw
                let tags = ["TEXT", "MATH", "GRAPH"]
                
                while !remainingContent.isEmpty {
                    var earliestTag: String? = nil
                    var earliestIndex: String.Index? = nil
                    
                    for tag in tags {
                        if let range = remainingContent.range(of: "[\(tag)]") {
                            if earliestIndex == nil || range.lowerBound < earliestIndex! {
                                earliestIndex = range.lowerBound
                                earliestTag = tag
                            }
                        }
                    }
                    
                    guard let startTag = earliestTag, let startIndex = earliestIndex else { break }
                    let endTagStr = "[/\(startTag)]"
                    
                    let contentStart = remainingContent.range(of: "[\(startTag)]")!.upperBound
                    remainingContent = String(remainingContent[contentStart...])
                    
                    if let endRange = remainingContent.range(of: endTagStr) {
                        let content = String(remainingContent[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        var block = QuestionBlockModel(
                            type: startTag == "TEXT" ? QuestionBlockType.text.rawValue : (startTag == "MATH" ? QuestionBlockType.math.rawValue : QuestionBlockType.graph.rawValue),
                            content: content
                        )
                        
                        remainingContent = String(remainingContent[endRange.upperBound...])
                        
                        if startTag == "MATH" {
                            let nextText = remainingContent.trimmingCharacters(in: .whitespacesAndNewlines)
                            if nextText.hasPrefix("[CAPTION]") {
                                if let captionEndRange = remainingContent.range(of: "[/CAPTION]") {
                                    let capStart = remainingContent.range(of: "[CAPTION]")!.upperBound
                                    let caption = String(remainingContent[capStart..<captionEndRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    block.caption = caption
                                    remainingContent = String(remainingContent[captionEndRange.upperBound...])
                                }
                            }
                        }
                        blocks.append(block)
                    } else {
                        break
                    }
                }
                
                if let data = try? JSONEncoder().encode(blocks), let json = String(data: data, encoding: .utf8) {
                    question.questionText = json
                }
            }
            
            // 2. Parse Multiple Choice Options
            if let oStart = qBlock.range(of: "[OPTIONS]"), let oEnd = qBlock.range(of: "[/OPTIONS]") {
                let optionsRaw = String(qBlock[oStart.upperBound..<oEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let lines = optionsRaw.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                
                var parsedOptions: [String] = []
                for (index, line) in lines.enumerated() {
                    let cleanLine = line.trimmingCharacters(in: .whitespaces)
                    if cleanLine.hasPrefix("*") {
                        question.correctOptionIndex = index
                        parsedOptions.append(String(cleanLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    } else {
                        parsedOptions.append(cleanLine)
                    }
                }
                while parsedOptions.count < 4 { parsedOptions.append("") }
                question.options = Array(parsedOptions.prefix(4))
            }
            
            // 3. Parse Metadata
            if let hStart = qBlock.range(of: "[HINT]"), let hEnd = qBlock.range(of: "[/HINT]") {
                question.hint = String(qBlock[hStart.upperBound..<hEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if let fStart = qBlock.range(of: "[FEEDBACK]"), let fEnd = qBlock.range(of: "[/FEEDBACK]") {
                question.feedback = String(qBlock[fStart.upperBound..<fEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            newWrappers.append(EditableQuestion(question: question))
        }

        if !newWrappers.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                // If there was only an empty placeholder, replace it. Otherwise append.
                if self.generatedQuestions.count == 1 && self.generatedQuestions.first?.question.questionText.isEmpty == true {
                    self.generatedQuestions = newWrappers
                } else {
                    self.generatedQuestions.append(contentsOf: newWrappers)
                }
            }
        }
    }
}

struct AddTestView: View {
    let subject: Subject
    let lessonName: String
    var existingTest: Test? = nil
    
    @State private var viewModel = TestBuilderViewModel()
    @State private var showingBulkImporter: Bool = false
    @State private var bulkImportText: String = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let emeraldAccent = Color(red: 0.15, green: 0.80, blue: 0.50)

    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            editorContent
        }
        .navigationTitle(existingTest != nil ? "Edit Assessment" : "Build Assessment")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingBulkImporter = true }) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.borderless)
                
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
            #endif
        }
        .task {
            await viewModel.initialize(subject: subject, lesson: lessonName, testId: existingTest?.id)
            if existingTest != nil {
                viewModel.testTitle = existingTest?.title ?? existingTest?.subject ?? "Untitled Test"
            }
        }
        .sheet(isPresented: $showingBulkImporter) {
            NavigationStack {
                VStack {
                    TextEditor(text: $bulkImportText)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(Color.platformSecondarySystemBackground)
                        .cornerRadius(12)
                        .padding()
                }
                .navigationTitle("Bulk Import Questions")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingBulkImporter = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            viewModel.processBulkQuestionImport(text: bulkImportText)
                            bulkImportText = ""
                            showingBulkImporter = false
                        }
                        .fontWeight(.bold)
                        .tint(.orange)
                    }
                }
                .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
            }
        }
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
                
                // Add Buttons Row
                HStack(spacing: 16) {
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
                    
                    Button(action: { showingBulkImporter = true }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard.fill")
                            Text("Bulk Import Questions")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.10))
                        .foregroundColor(.orange)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
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
                    UniversalBlockEditorView(blocks: $blocks, hideBulkImport: true)
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
