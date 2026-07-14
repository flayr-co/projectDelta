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
    @Environment(\.dismiss) var dismiss
    
    let mathSubtopics: [String: [String]] = [
        "Algebra": ["Linear Equations", "Systems of Equations", "Inequalities", "Functions"],
        "Advanced Math": ["Polynomials", "Rational Expressions", "Exponents", "Radicals"],
        "Problem Solving and Data Analysis": ["Ratios", "Percentages", "Probability", "Statistics"],
        "Geometry and Trigonometry": ["Area & Volume", "Right Triangles", "Circle Theorems", "Trig Identities"]
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Architect Question")
                        .font(.title)
                        .fontWeight(.heavy)
                    Text("Construct independent database modules for \(subject.name).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 16)
                
                categorizationCard
                questionBuilderCard
                optionsCard
                assistanceCard
                
                Spacer(minLength: 80)
            }
        }
        .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                
                Button("Commit") { saveQuestion() }
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(questionBlocks.isEmpty || options.contains(where: \.isEmpty))
            }
            #endif
        }
        .onAppear {
            if let initialArea = SubjectArea(rawValue: subject.name) ?? SubjectArea(rawValue: subject.subjectArea.rawValue) {
                selectedSubjectArea = initialArea
            }
            let safeSubtopic: String = (test.subtopic as? String) ?? ""
            selectedSubtopic = safeSubtopic.isEmpty ? (mathSubtopics[selectedSubjectArea.rawValue]?.first ?? "") : safeSubtopic
        }
        .alert("Database Synced", isPresented: $viewModel.showSubmissionSuccessAlert) {
            Button("Acknowledge", role: .cancel) { dismiss() }
        } message: {
            Text("The question has been successfully deployed to the global bank and linked to the assessment.")
        }
        #if os(iOS)
        .safeAreaInset(edge: .bottom) {
            Button(action: saveQuestion) {
                HStack {
                    Image(systemName: "server.rack")
                    Text("Commit to Database")
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
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(Color.platformSystemGroupedBackground.opacity(0.95))
        }
        #endif
    }
    
    // MARK: - Sub-Builders
    
    @ViewBuilder
    private var categorizationCard: some View {
        FormCard(title: "Routing Taxonomy", icon: "folder.fill", iconColor: .blue) {
            VStack(spacing: 16) {
                HStack {
                    Text("Subject")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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
    }
    
    @ViewBuilder
    private var questionBuilderCard: some View {
        FormCard(title: "Problem Canvas", icon: "hammer.fill", iconColor: .purple) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inject equations and graphs utilizing the block engine.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                UniversalBlockEditorView(blocks: $questionBlocks)
            }
        }
    }
    
    @ViewBuilder
    private var optionsCard: some View {
        FormCard(title: "Evaluation Parameters", icon: "checklist", iconColor: .orange) {
            VStack(alignment: .leading, spacing: 16) {
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
                                    .foregroundColor(correctIndex == index ? .green : .gray.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            
                            TextField("Vector \(index + 1)", text: $options[index])
                                .padding(12)
                                .background(Color.platformSecondarySystemBackground)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var assistanceCard: some View {
        FormCard(title: "Contextual Hint", icon: "lightbulb.fill", iconColor: .yellow) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Provide diagnostic guidance...", text: $hint, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.platformSecondarySystemBackground)
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Logic
    
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
            if let subjectId = subject.id, let testId = test.id {
                await viewModel.saveQuestionToTest(subjectId: subjectId, testId: testId, question: newQuestion)
            }
        }
    }
}

// MARK: - Helper UI Component
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
            
            Divider()
            
            content
        }
        .padding()
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}
