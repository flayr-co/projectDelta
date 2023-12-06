//
//  AddQuestionView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 11/27/23.
//

// AddQuestionView.swift
import SwiftUI

struct AddQuestionView: View {
    @StateObject var viewModel = QuestionGeneratorViewModel()
    @State private var options: [String] = ["", "", "", ""]
    @State private var correctOptionIndex: Int = 0
    
    var body: some View {
        VStack {
            // Subjects Display
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.subjects, id: \.id) { subject in
                        Text(subject.name)
                            .padding()
                            .background(viewModel.selectedSubjectId == subject.id ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .onTapGesture {
                                viewModel.selectedSubjectId = subject.id
                                viewModel.selectedTestId = nil // Reset selectedTestId when a subject is selected
                                viewModel.tests = []
                                viewModel.fetchTestsForSubject(subjectId: subject.id)
                            }
                    }
                }
            }
            .padding()
            .onAppear {
                viewModel.fetchSubjects()
            }
            
            // Tests Display
            if let selectedSubjectId = viewModel.selectedSubjectId, !viewModel.tests.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.tests, id: \.id) { test in
                            Text(test.name) // Assuming test.name now contains the testIdentifier
                                .padding()
                                .background(viewModel.selectedTestId == test.id ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .onTapGesture {
                                    viewModel.selectedTestId = test.id // Set selectedTestId when a test is selected
                                }
                        }
                    }
                }
                .padding()
            } else if viewModel.selectedSubjectId != nil {
                Text("Loading tests...")
            }
            
            // Generate Question Button
            if viewModel.selectedSubjectId != nil && viewModel.selectedTestId != nil {
                Button("Generate Question") {
                    viewModel.generateQuestion(subjectId: viewModel.selectedSubjectId!, testId: viewModel.selectedTestId!)
                }
                .padding()
            }
            
            // Approval View
            if viewModel.isApprovalViewPresented, let question = viewModel.generatedQuestion {
                VStack {
                    Text("Generated Question: \(question.questionText)")
                    ForEach(Array(zip(options.indices, $options)), id: \.0) { index, optionBinding in
                        TextField("Option \(index + 1)", text: optionBinding)
                    }
                    Picker("Correct Option", selection: $correctOptionIndex) {
                        ForEach(0..<options.count, id: \.self) {
                            Text("Option \($0 + 1)")
                        }
                    }
                    Button("Approve and Add Question") {
                        // Update the question with the edited options and correct option index before saving
                        var updatedQuestion = question
                        updatedQuestion.options = options
                        updatedQuestion.correctOptionIndex = correctOptionIndex
                        
                        viewModel.generatedQuestion = updatedQuestion
                        viewModel.saveQuestion() {
                            // This is the completion block that will be executed after the question is saved
                            options = ["", "", "", ""] // Reset the options to empty strings
                            correctOptionIndex = 0 // Reset the correct option index to its default
                        }
                    }
                }
                .padding()
            }
        } //: VSTACK
        .onAppear {
            // When the approval view is presented, initialize the options and correct option index
            if let question = viewModel.generatedQuestion {
                options = question.options
                correctOptionIndex = question.correctOptionIndex
            }
        }
    }
}

#Preview {
    AddQuestionView()
}
