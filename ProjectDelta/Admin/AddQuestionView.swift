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
    
    let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    let mathSubtopics: [String: [String]] = [
        "Algebra": ["Linear Equations", "Systems of Equations", "Inequalities", "Functions"],
        "Advanced Math": ["Polynomials", "Rational Expressions", "Exponents", "Radicals"],
        "Problem Solving and Data Analysis": ["Ratios", "Percentages", "Probability", "Statistics"],
        "Geometry and Trigonometry": ["Area & Volume", "Right Triangles", "Circle Theorems", "Trig Identities"]
    ]
    
    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Premium Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Architect Question")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.primary, primaryTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("Construct independent database modules for \(subject.name).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    categorizationCard
                    questionBuilderCard
                    optionsCard
                    assistanceCard
                    
                    Spacer(minLength: 120)
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                
                Button("Commit Question") { saveQuestion() }
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .tint(primaryTeal)
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
                        .font(.system(size: 18, weight: .bold))
                    Text("Commit to Database")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(primaryTeal.gradient)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: primaryTeal.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(questionBlocks.isEmpty || options.contains(where: \.isEmpty))
            .opacity(questionBlocks.isEmpty || options.contains(where: \.isEmpty) ? 0.5 : 1.0)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 16)
            .background(.ultraThinMaterial)
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
                Text("Inject equations and graphs utilizing the universal block engine.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                UniversalBlockEditorView(blocks: $questionBlocks)
            }
        }
    }
    
    @ViewBuilder
    private var optionsCard: some View {
        FormCard(title: "Evaluation Parameters", icon: "checklist", iconColor: .orange) {
            VStack(spacing: 16) {
                ForEach(options.indices, id: \.self) { index in
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                correctIndex = index
                            }
                        }) {
                            Image(systemName: correctIndex == index ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(correctIndex == index ? primaryTeal : .gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        
                        TextField("Vector \(index + 1)", text: $options[index])
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(16)
                            .background(Color.platformSecondarySystemBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(correctIndex == index ? primaryTeal : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var assistanceCard: some View {
        FormCard(title: "Contextual Hint", icon: "lightbulb.fill", iconColor: .yellow) {
            TextField("Provide diagnostic guidance...", text: $hint, axis: .vertical)
                .lineLimit(3...6)
                .padding(16)
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
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

// MARK: - Premium Glass Form Card
struct FormCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    @State private var isHovered = false
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.gradient.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 20, weight: .bold))
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            
            Divider()
            
            content
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 15 : 10, y: isHovered ? 8 : 5)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 24)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
