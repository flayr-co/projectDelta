//
//  AddTestView.swift
//  ProjectDelta
//

import SwiftUI

struct AddTestView: View {
    var viewModel: AdminViewModel
    var subject: Subject
    
    @State private var subtopic: String = ""
    @State private var testIdentifier: Int = 1
    @State private var questionAmount: Int = 10
    @State private var timeLimit: Int = 20
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSubjectArea: SubjectArea = .algebra
    @State private var selectedSubtopic: String = ""
    
    let mathSubtopics: [String: [String]] = [
        SubjectArea.algebra.rawValue: ["Linear Equations", "Systems of Equations", "Inequalities", "Functions"],
        SubjectArea.advancedMath.rawValue: ["Polynomials", "Rational Expressions", "Exponents", "Radicals"],
        SubjectArea.problemSolvingDataAnalysis.rawValue: ["Ratios", "Percentages", "Probability", "Statistics"],
        SubjectArea.geometryTrigonometry.rawValue: ["Area & Volume", "Right Triangles", "Circle Theorems", "Trig Identities"]
    ]
    
    var body: some View {
        Form {
            Section("Subject & Subtopic") {
                Picker("Subject", selection: $selectedSubjectArea) {
                    ForEach(SubjectArea.allCases) { area in
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
            
            Section("Test Setup") {
                Stepper("Test Identifier: \(testIdentifier)", value: $testIdentifier, in: 1...100)
            }
            
            Section("Constraints") {
                Stepper("Questions: \(questionAmount)", value: $questionAmount, in: 1...50)
                Stepper("Time Limit: \(timeLimit) mins", value: $timeLimit, in: 1...120)
            }
            
            Button("Create Test") {
                let newTest = Test(
                    questionAmount: questionAmount,
                    subject: selectedSubjectArea.rawValue,
                    testIdentifier: testIdentifier,
                    timeLimit: timeLimit,
                    subtopic: selectedSubtopic
                )
                Task {
                    // Defaults to using the raw string value (e.g. "Algebra") as the Firestore document ID to match SubjecGridView architecture
                    let idToSave = subject.id ?? selectedSubjectArea.rawValue
                    await viewModel.addTest(subjectId: idToSave, test: newTest)
                    dismiss()
                }
            }
        }
        .navigationTitle("New Test")
        .onAppear {
            if let initialArea = SubjectArea(rawValue: subject.name) ?? SubjectArea(rawValue: subject.subjectArea.rawValue) {
                selectedSubjectArea = initialArea
            }
            selectedSubtopic = mathSubtopics[selectedSubjectArea.rawValue]?.first ?? ""
        }
    }
}
