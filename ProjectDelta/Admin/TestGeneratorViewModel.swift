//
//  TestGeneratorViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 8/13/26.
//


import SwiftUI
import FirebaseFirestore // Assuming Firestore based on your project structure

@Observable
final class TestGeneratorViewModel {
    var selectedSubjectId: String = ""
    var selectedLessonId: String = ""
    var isGenerating: Bool = false
    var isSaving: Bool = false
    var generatedQuestions: [Question] = []
    var errorMessage: String? = nil

    /// Triggers the test generation process.
    func generateTest() async {
        guard !selectedSubjectId.isEmpty, !selectedLessonId.isEmpty else {
            errorMessage = "Subject and Lesson IDs are required."
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            // TODO: Replace with your actual LLM or backend generation API endpoint
            // This is a simulated network request for the generation process.
            try await Task.sleep(for: .seconds(3))
            
            // Simulating 10 generated questions
            let mockQuestions = (1...10).map { index in
                Question(
                    id: UUID().uuidString,
                    correctOptionIndex: 0,
                    options: ["Option A", "Option B", "Option C", "Option D"],
                    points: 10,
                    questionText: "Generated Question \(index) for Lesson?",
                    type: "multiple_choice",
                    subject: selectedSubjectId,
                    subtopic: selectedLessonId,
                    hint: nil,
                    feedback: "Generated explanation for question \(index).",
                    testId: nil
                )
            }
            
            await MainActor.run {
                self.generatedQuestions = mockQuestions
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate tests: \(error.localizedDescription)"
                self.isGenerating = false
            }
        }
    }
    
    /// Commits the edited questions to the database.
    func saveGeneratedTest() async {
        isSaving = true
        errorMessage = nil
        
        do {
            // TODO: Replace with your FirestoreManager save logic
            // e.g., try await FirestoreManager.shared.saveQuestions(generatedQuestions, to: selectedLessonId)
            try await Task.sleep(for: .seconds(1))
            
            await MainActor.run {
                self.generatedQuestions.removeAll()
                self.isSaving = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save test: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }
}
