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
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        showEditor = true
        isGenerating = false
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        
        // Save logic to Firebase would go here
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isSaving = false
    }
}

struct AddTestView: View {
    // Added to satisfy initialization from AdminView
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
            // Passes existing test ID to trigger the Firebase fetch logic dynamically
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
                
                Section(header: Text("Questions")) {
                    ForEach(viewModel.generatedQuestions.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Question Text", text: Binding(
                                get: { viewModel.generatedQuestions[index].questionText },
                                set: { viewModel.generatedQuestions[index].questionText = $0 }
                            ), axis: .vertical)
                            .font(.body)
                            .fontWeight(.bold)
                            
                            // 4 Options per question
                            ForEach(0..<4, id: \.self) { optIndex in
                                HStack {
                                    Image(systemName: viewModel.generatedQuestions[index].correctOptionIndex == optIndex ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(viewModel.generatedQuestions[index].correctOptionIndex == optIndex ? .green : .gray)
                                        .onTapGesture {
                                            viewModel.generatedQuestions[index].correctOptionIndex = optIndex
                                        }
                                    
                                    TextField("Option \(optIndex + 1)", text: Binding(
                                        get: {
                                            guard optIndex < viewModel.generatedQuestions[index].options.count else { return "" }
                                            return viewModel.generatedQuestions[index].options[optIndex]
                                        },
                                        set: { newValue in
                                            // Pad the array if needed to prevent index out of bounds
                                            while viewModel.generatedQuestions[index].options.count <= optIndex {
                                                viewModel.generatedQuestions[index].options.append("")
                                            }
                                            viewModel.generatedQuestions[index].options[optIndex] = newValue
                                        }
                                    ))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
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
