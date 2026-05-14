//
//  AddQuestionView.swift
//  ProjectDelta
//

import SwiftUI

struct AddQuestionView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    var test: Test
    
    @State private var questionText: String = ""
    @State private var options: [String] = ["", "", "", ""]
    @State private var correctIndex: Int = 0
    @State private var hint: String = ""
    
    var body: some View {
        Form {
            Section("Question Text") {
                TextEditor(text: $questionText)
                    .frame(height: 100)
            }
            
            Section("Options") {
                ForEach(options.indices, id: \.self) { index in
                    HStack {
                        TextField("Option \(index + 1)", text: $options[index])
                        if correctIndex == index {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { correctIndex = index }
                }
            }
            
            Section("Assistance") {
                TextField("Hint", text: $hint)
            }
            
            Button("Save Question") {
                // The explicit memberwise initializer requires precise ordering and all non-optional properties
                let newQuestion = Question(
                    correctOptionIndex: correctIndex,
                    options: options,
                    points: 10, // Default point value added
                    questionText: questionText,
                    type: "multiple_choice", // Default type added
                    subject: subject.name,
                    subtopic: test.subtopic,
                    hint: hint.isEmpty ? nil : hint,
                    feedback: nil, // Default feedback added
                    testId: test.id
                )
                
                Task {
                    await viewModel.saveQuestion(question: newQuestion)
                    questionText = ""
                    options = ["", "", "", ""]
                    hint = ""
                    correctIndex = 0
                }
            }
            .disabled(questionText.isEmpty || options.contains(where: \.isEmpty))
        }
        .navigationTitle("Add Question")
        .alert("Saved", isPresented: $viewModel.showSubmissionSuccessAlert) {
            Button("OK") { }
        }
    }
}
