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
    
    @State private var selectedSubjectArea: SubjectArea = .algebra
    @State private var selectedSubtopic: String = ""
    
    // Aligned the dictionary keys to exact string literals to prevent compilation scope errors
    let mathSubtopics: [String: [String]] = [
        "Algebra": ["Linear Equations", "Systems of Equations", "Inequalities", "Functions"],
        "Advanced Math": ["Polynomials", "Rational Expressions", "Exponents", "Radicals"],
        "Problem Solving and Data Analysis": ["Ratios", "Percentages", "Probability", "Statistics"],
        "Geometry and Trigonometry": ["Area & Volume", "Right Triangles", "Circle Theorems", "Trig Identities"]
    ]
    
    var body: some View {
        Form {
            Section("Subject & Subtopic") {
                Picker("Subject", selection: $selectedSubjectArea) {
                    // Requires id: \.self since SubjectArea is not natively Identifiable
                    ForEach(SubjectArea.allCases, id: \.self) { area in
                        Text(area.rawValue).tag(area)
                    }
                }
                .onChange(of: selectedSubjectArea) { _, newValue in
                    selectedSubtopic = mathSubtopics[newValue.rawValue]?.first ?? ""
                }
                
                Picker("Subtopic", selection: $selectedSubtopic) {
                    ForEach(mathSubtopics[selectedSubjectArea.rawValue] ?? [], id: \.self) { subtopic in
                        Text(subtopic).tag(subtopic)
                    }
                }
            }
            
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
                let newQuestion = Question(
                    correctOptionIndex: correctIndex,
                    options: options,
                    points: 10,
                    questionText: questionText,
                    type: "multiple_choice",
                    subject: selectedSubjectArea.rawValue,
                    subtopic: selectedSubtopic,
                    hint: hint.isEmpty ? nil : hint,
                    feedback: nil,
                    testId: test.id ?? ""
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
        .onAppear {
            if let initialArea = SubjectArea(rawValue: subject.name) ?? SubjectArea(rawValue: subject.subjectArea.rawValue) {
                selectedSubjectArea = initialArea
            }
            
            // Safe extraction ensuring compilation whether Test.subtopic is Optional or non-Optional
            let safeSubtopic: String
            if let s = test.subtopic as Any as? String {
                safeSubtopic = s
            } else {
                safeSubtopic = ""
            }
            
            selectedSubtopic = safeSubtopic.isEmpty ? (mathSubtopics[selectedSubjectArea.rawValue]?.first ?? "") : safeSubtopic
        }
        .alert("Saved", isPresented: $viewModel.showSubmissionSuccessAlert) {
            Button("OK") { }
        }
    }
}
