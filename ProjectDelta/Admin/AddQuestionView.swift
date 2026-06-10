//
//  AddQuestionView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

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
        ScrollView {
            VStack(spacing: 24) {
                // 1. Categorization Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("Categorization", systemImage: "folder.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Subject")
                                .fontWeight(.medium)
                            Spacer()
                            Picker("Subject", selection: $selectedSubjectArea) {
                                ForEach(SubjectArea.allCases, id: \.self) { area in
                                    Text(area.rawValue).tag(area)
                                }
                            }
                            .tint(.blue)
                        }
                        .onChange(of: selectedSubjectArea) { _, newValue in
                            selectedSubtopic = mathSubtopics[newValue.rawValue]?.first ?? ""
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Subtopic")
                                .fontWeight(.medium)
                            Spacer()
                            Picker("Subtopic", selection: $selectedSubtopic) {
                                ForEach(mathSubtopics[selectedSubjectArea.rawValue] ?? [], id: \.self) { subtopic in
                                    Text(subtopic).tag(subtopic)
                                }
                            }
                            .tint(.blue)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                
                // 2. Question Builder
                VStack(alignment: .leading, spacing: 16) {
                    Label("Question Builder", systemImage: "hammer.fill")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    UniversalBlockEditorView(blocks: $questionBlocks)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                
                // 3. Multiple Choice Options
                VStack(alignment: .leading, spacing: 16) {
                    Label("Multiple Choice Answers", systemImage: "checklist")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("Select the circle next to the correct answer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        ForEach(options.indices, id: \.self) { index in
                            HStack {
                                Button(action: {
                                    withAnimation { correctIndex = index }
                                }) {
                                    Image(systemName: correctIndex == index ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundColor(correctIndex == index ? .green : .gray.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                
                                TextField("Option \(index + 1)", text: $options[index])
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                
                // 4. Assistance
                VStack(alignment: .leading, spacing: 16) {
                    Label("Assistance (Optional)", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    
                    TextField("Enter a hint to help students...", text: $hint, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                
                // 5. Submit Button
                Button(action: saveQuestion) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save Question to Database")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.teal, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .disabled(questionBlocks.isEmpty || options.contains(where: \.isEmpty))
                .opacity(questionBlocks.isEmpty || options.contains(where: \.isEmpty) ? 0.6 : 1.0)
            }
            .padding()
        }
        // This natively forces the bottom boundary of the scroll view up, rescuing the button from the tab bar
        .safeAreaPadding(.bottom, 120)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Add Question")
        .navigationBarTitleDisplayMode(.inline)
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
        .alert("Saved Successfully", isPresented: $viewModel.showSubmissionSuccessAlert) {
            Button("OK", role: .cancel) { }
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
            withAnimation {
                questionBlocks = []
                options = ["", "", "", ""]
                hint = ""
                correctIndex = 0
            }
        }
    }
}
