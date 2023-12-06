//
//  AddTestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 12/2/23.
//

// AddTestView.swift
import SwiftUI
import Firebase
import FirebaseFirestoreSwift

struct AddTestView: View {
    // MARK: - PROPERTIES
    @StateObject var viewModel = QuestionGeneratorViewModel()
    @State private var selectedSubjectId: String? = nil
    @State private var testIdentifier: Int = 0
    @State private var questionAmount: Int = 0
    @State private var timeLimit: Int = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    
    var body: some View {
        VStack {
            // Subjects Display
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.subjects, id: \.id) { subject in
                        Text(subject.name)
                            .padding()
                            .background(selectedSubjectId == subject.id ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .onTapGesture {
                                self.selectedSubjectId = subject.id
                                // No need to reset or reference 'selectedTestId' when a subject is selected
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
            
            // Test Details Input
            Form {
                Section(header: Text("Test Details")) {
                    HStack {
                        Text("Test Identifier:")
                        TextField("Identifier", value: $testIdentifier, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("Question Amount:")
                        TextField("Amount", value: $questionAmount, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("Time Limit (minutes):")
                        TextField("Limit", value: $timeLimit, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                }
                Button("Add Test") {
                    addTest()
                }
                    .alert(isPresented: $showingAlert) {
                        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
            }
            .padding()
        } //: VSTACK
        .onAppear {
            viewModel.fetchSubjects()
        }
    }
    
    func addTest() {
        guard let subjectId = selectedSubjectId, let subjectName = viewModel.subjects.first(where: { $0.id == subjectId })?.name else {
            self.alertMessage = "Please select a subject first."
            self.showingAlert = true
            return
        }
        // Check if the testIdentifier is already taken
        Firestore.firestore().collection("Subjects").document(subjectId).collection("Tests").whereField("testIdentifier", isEqualTo: testIdentifier).getDocuments { (querySnapshot, error) in
            if let error = error {
                self.alertMessage = "Error: \(error.localizedDescription)"
                self.showingAlert = true
            } else if let querySnapshot = querySnapshot, querySnapshot.documents.isEmpty {
                // No existing test with the same identifier, proceed to add
                let newTest = Test(questionAmount: questionAmount, subject: subjectName, testIdentifier: testIdentifier, timeLimit: timeLimit)
                FirestoreManager().saveTest(subjectId: subjectId, test: newTest) { result in
                    switch result {
                    case .success(let docId):
                        print("Test added successfully with ID: \(docId ?? "Unknown ID")")
                    case .failure(let error):
                        self.alertMessage = "Error adding test: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                }
            } else {
                // Found existing test with the same identifier
                self.alertMessage = "A test with this identifier already exists."
                self.showingAlert = true
            }
        }
    }
}

#Preview {
    AddTestView()
}
