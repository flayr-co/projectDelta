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
                
                // Instructions Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manual Question Entry")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Build a custom question for your students. Use the block editor to seamlessly mix text, math equations, and graphs.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // 1. Categorization Card
                FormCard(title: "Categorization", icon: "folder.fill", iconColor: .blue) {
                    VStack(spacing: 16) {
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
                }
                
                // 2. Question Builder
                FormCard(title: "Question Content", icon: "hammer.fill", iconColor: .purple) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add text, LaTeX math, or dynamic graphs using the tools below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        UniversalBlockEditorView(blocks: $questionBlocks)
                    }
                }
                
                // 3. Multiple Choice Options
                FormCard(title: "Answer Choices", icon: "checklist", iconColor: .orange) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter the possible answers and tap the circle next to the correct one.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            ForEach(options.indices, id: \.self) { index in
                                HStack(spacing: 12) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            correctIndex = index
                                        }
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
                }
                
                // 4. Assistance
                FormCard(title: "Assistance (Optional)", icon: "lightbulb.fill", iconColor: .yellow) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Provide a hint to point struggling students in the right direction.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., Remember to isolate the variable first...", text: $hint, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                    }
                }
                
                // 5. Submit Button
                Button(action: saveQuestion) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save to Database")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.teal.opacity(0.3), radius: 10, y: 5)
                }
                .disabled(questionBlocks.isEmpty || options.contains(where: \.isEmpty))
                .opacity(questionBlocks.isEmpty || options.contains(where: \.isEmpty) ? 0.5 : 1.0)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .safeAreaPadding(.bottom, 100)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("New Question")
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

// MARK: - Helper UI Component
// Move this to a generic components file if needed elsewhere
struct FormCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.subheadline)
                }
                
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}
