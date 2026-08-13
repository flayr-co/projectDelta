//
//  TestGeneratorView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 8/13/26.
//


import SwiftUI

struct TestGeneratorView: View {
    @State private var viewModel = TestGeneratorViewModel()
    
    var body: some View {
        Form {
            Section("Target Identification") {
                TextField("Subject ID", text: $viewModel.selectedSubjectId)
                TextField("Lesson ID", text: $viewModel.selectedLessonId)
                
                Button(action: {
                    Task {
                        await viewModel.generateTest()
                    }
                }) {
                    if viewModel.isGenerating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Generate 10-Question Test")
                    }
                }
                .disabled(viewModel.isGenerating || viewModel.selectedSubjectId.isEmpty || viewModel.selectedLessonId.isEmpty)
            }
            
            if !viewModel.generatedQuestions.isEmpty {
                Section("Review and Edit") {
                    ForEach($viewModel.generatedQuestions, id: \.id) { $question in
                        DisclosureGroup("Question: \($question.questionText.wrappedValue.prefix(20))...") {
                            TextField("Question Text", text: $question.questionText, axis: .vertical)
                            
                            ForEach(0..<4, id: \.self) { index in
                                TextField("Option \(index + 1)", text: Binding(
                                    get: { $question.options.wrappedValue.indices.contains(index) ? $question.options.wrappedValue[index] : "" },
                                    set: { if $question.options.wrappedValue.indices.contains(index) { $question.options.wrappedValue[index] = $0 } }
                                ))
                            }
                            
                            Stepper("Correct Answer Index: \($question.correctOptionIndex.wrappedValue)", value: $question.correctOptionIndex, in: 0...3)
                            
                            TextField("Feedback", text: Binding(
                                get: { $question.feedback.wrappedValue ?? "" },
                                set: { $question.feedback.wrappedValue = $0.isEmpty ? nil : $0 }
                            ), axis: .vertical)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.saveGeneratedTest()
                        }
                    }) {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Save Test to Database")
                                .bold()
                                .foregroundStyle(.green)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .navigationTitle("Test Generator")
        .overlay {
            if let error = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .padding()
                        .background(.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                        .padding(.bottom)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TestGeneratorView()
    }
}
