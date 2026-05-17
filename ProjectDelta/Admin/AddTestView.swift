//
//  AddTestView.swift
//  ProjectDelta
//

import SwiftUI

struct AddTestView: View {
    var viewModel: AdminViewModel
    var subject: Subject
    
    @State private var testIdentifier: Int = 1
    @State private var questionAmount: Int = 10
    @State private var timeLimit: Int = 20
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSubjectArea: SubjectArea = .algebra
    @State private var selectedLesson: String = ""
    
    let mathLessons: [String: [String]] = [
        "Algebra": ["Linear Equations", "Systems of Equations", "Inequalities", "Functions"],
        "Advanced Math": ["Polynomials", "Rational Expressions", "Exponents", "Radicals"],
        "Problem Solving and Data Analysis": ["Ratios", "Percentages", "Probability", "Statistics"],
        "Geometry and Trigonometry": ["Area & Volume", "Right Triangles", "Circle Theorems", "Trig Identities"]
    ]
    
    var body: some View {
        Form {
            Section("Subject & Lesson") {
                Picker("Subject", selection: $selectedSubjectArea) {
                    ForEach(SubjectArea.allCases, id: \.self) { area in
                        Text(area.rawValue).tag(area)
                    }
                }
                .onChange(of: selectedSubjectArea) { _, newValue in
                    selectedLesson = mathLessons[newValue.rawValue]?.first ?? ""
                }
                
                Picker("Lesson", selection: $selectedLesson) {
                    ForEach(mathLessons[selectedSubjectArea.rawValue] ?? [], id: \.self) { lesson in
                        Text(lesson).tag(lesson)
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
                    subtopic: selectedLesson
                )
                Task {
                    let idToSave = subject.id ?? selectedSubjectArea.rawValue
                    await viewModel.addTest(subjectId: idToSave, test: newTest)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("New Test")
        .onAppear {
            if let initialArea = SubjectArea(rawValue: subject.name) ?? SubjectArea(rawValue: subject.subjectArea.rawValue) {
                selectedSubjectArea = initialArea
            }
            selectedLesson = mathLessons[selectedSubjectArea.rawValue]?.first ?? ""
        }
    }
}
