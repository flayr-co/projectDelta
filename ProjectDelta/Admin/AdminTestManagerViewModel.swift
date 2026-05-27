//
//  AdminTestManagerViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/27/26.
//


//
//  AdminTestManagerView.swift
//  ProjectDelta
//
//  Created for Admin Test Generation & Editing Flow
//

import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
class AdminTestManagerViewModel {
    var subjectName: String = "Algebra"
    var lessonName: String = "Linear Equations"
    var generatedQuestions: [Question] = []
    
    var isGenerating: Bool = false
    var isSaving: Bool = false
    var showEditor: Bool = false
    
    private let db = Firestore.firestore()
    
    /// Auto-generates a 10-question template for the selected lesson/subject framework
    func generateRecommendedTest() async {
        isGenerating = true
        
        // Simulating the LLM/Network delay for test generation. 
        // Replace this block with your actual server-side API call if needed.
        try? await Task.sleep(for: .seconds(1.5))
        
        var newQuestions: [Question] = []
        for i in 1...10 {
            let question = Question(
                id: UUID().uuidString,
                questionText: "Recommended Question \(i) covering \(lessonName)",
                options: ["Option A", "Option B", "Option C", "Option D"],
                correctOptionIndex: 0,
                hint: "Review the standard properties of \(lessonName).",
                feedback: "Option A is correct based on foundational logic.",
                subject: subjectName,
                subtopic: lessonName
            )
            newQuestions.append(question)
        }
        
        generatedQuestions = newQuestions
        isGenerating = false
        showEditor = true
    }
    
    /// Commits the newly generated and edited test securely to Firestore
    func saveTestToDatabase() async {
        isSaving = true
        do {
            let batch = db.batch()
            
            // 1. Create the hierarchical Test Document
            let testId = UUID().uuidString
            let testRef = db.collection("Tests").document(testId)
            let testData: [String: Any] = [
                "id": testId,
                "subject": subjectName,
                "lesson": lessonName,
                "title": "\(lessonName) Test",
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef)
            
            // 2. Batch write questions to both hierarchical and flat collections to guarantee seamless fetching across legacy logic
            for question in generatedQuestions {
                let docData: [String: Any] = [
                    "id": question.id ?? UUID().uuidString,
                    "subject": subjectName,
                    "subtopic": lessonName,
                    "questionText": question.questionText,
                    "options": question.options,
                    "correctOptionIndex": question.correctOptionIndex,
                    "hint": question.hint ?? "",
                    "feedback": question.feedback ?? ""
                ]
                
                // Write to hierarchical subcollection
                let subRef = testRef.collection("Questions").document(question.id ?? UUID().uuidString)
                batch.setData(docData, forDocument: subRef)
                
                // Write to flat fallback collection
                let flatRef = db.collection("questions").document(question.id ?? UUID().uuidString)
                batch.setData(docData, forDocument: flatRef)
            }
            
            try await batch.commit()
            generatedQuestions.removeAll()
            showEditor = false
        } catch {
            print("Failed to save test to database: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

struct AdminTestManagerView: View {
    @State private var viewModel = AdminTestManagerViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.customDarkGray : Color.white).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if !viewModel.showEditor {
                        setupView
                    } else {
                        editorView
                    }
                }
            }
            .navigationTitle(viewModel.showEditor ? "Edit Test" : "Generate Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(.red)
                }
            }
        }
    }
    
    private var setupView: some View {
        VStack(spacing: 24) {
            Text("Test Generator")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Subject")
                    .font(.headline)
                TextField("e.g. Algebra", text: $viewModel.subjectName)
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
        VStack {
            List {
                ForEach($viewModel.generatedQuestions) { $question in
                    Section(header: Text("Question").font(.headline)) {
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            
            Button(action: {
                Task { await viewModel.saveTestToDatabase() }
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
        }
    }
}

#Preview {
    AdminTestManagerView()
}