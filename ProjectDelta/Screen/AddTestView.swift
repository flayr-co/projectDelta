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
    
    var body: some View {
        Form {
            Section("Test Setup") {
                TextField("Subtopic", text: $subtopic)
                Stepper("Test Identifier: \(testIdentifier)", value: $testIdentifier, in: 1...100)
            }
            
            Section("Constraints") {
                Stepper("Questions: \(questionAmount)", value: $questionAmount, in: 1...50)
                Stepper("Time Limit: \(timeLimit) mins", value: $timeLimit, in: 1...120)
            }
            
            Button("Create Test") {
                let newTest = Test(
                    questionAmount: questionAmount,
                    subject: subject.name,
                    testIdentifier: testIdentifier,
                    timeLimit: timeLimit,
                    subtopic: subtopic
                )
                Task {
                    await viewModel.addTest(subjectId: subject.id ?? "", test: newTest)
                    dismiss()
                }
            }
        }
        .navigationTitle("New Test")
    }
}
