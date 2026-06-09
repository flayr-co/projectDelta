//
//  AddQuestionView.swift
//  ProjectDelta
//

import SwiftUI

struct AddQuestionView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    var test: Test
    
    @State private var questionBlocks: [QuestionBlockModel] = []
    @State private var options: [String] = ["", "", "", ""]
    @State private var correctIndex: Int = 0
    @State private var hint: String = ""
    
    @State private var selectedSubjectArea: SubjectArea = .algebra
    @State private var selectedSubtopic: String = ""
    
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
            
            Section("Question Content") {
                UniversalBlockEditorView(blocks: $questionBlocks)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
            }
            
            Section("Options") {
                ForEach(options.indices, id: \.self) { index in
                    HStack {
                        TextField("Option \(index + 1)", text: $options[index])
                        if correctIndex == index {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle").foregroundStyle(.gray.opacity(0.5))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { correctIndex = index }
                }
            }
            
            Section("Assistance") {
                TextField("Hint (Optional)", text: $hint)
            }
            
            Button(action: saveQuestion) {
                Text("Save Question")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(questionBlocks.isEmpty || options.contains(where: \.isEmpty))
        }
        .navigationTitle("Add Question")
        .onAppear {
            if let initialArea = SubjectArea(rawValue: subject.name) ?? SubjectArea(rawValue: subject.subjectArea.rawValue) {
                selectedSubjectArea = initialArea
            }
            
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
    
    private func saveQuestion() {
        var newQuestion = Question(
            correctOptionIndex: correctIndex,
            options: options,
            points: 10,
            questionText: "",
            type: "multiple_choice",
            subject: selectedSubjectArea.rawValue,
            subtopic: selectedSubtopic,
            hint: hint.isEmpty ? nil : hint,
            feedback: nil,
            testId: test.id ?? ""
        )
        
        newQuestion.updateWith(blocks: questionBlocks)
        
        Task {
            await viewModel.saveQuestion(question: newQuestion)
            questionBlocks = []
            options = ["", "", "", ""]
            hint = ""
            correctIndex = 0
        }
    }
}
