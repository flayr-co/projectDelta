//
//  LinearEquationTemplate.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 8/13/26.
//


//
//  LinearEquationTemplate.swift
//  ProjectDelta
//

import Foundation

struct LinearEquationTemplate: QuestionTemplate {
    let subject = "Algebra"
    let subtopic = "Linear Equations"
    
    func generate(testId: String?) -> QuestionWrapper {
        // 1. Parameter Bounds (Ensures clean integer answers)
        let a = Int.random(in: 2...12)
        let x = Int.random(in: -12...12)
        let b = Int.random(in: -20...20)
        let c = (a * x) + b
        
        // 2. Formatting & LaTeX Compilation
        let signB = b >= 0 ? "+ \(b)" : "- \(abs(b))"
        let equationLaTeX = "$\(a)x \(signB) = \(c)$"
        
        // 3. Deterministic Distractor Generation (Misconception Mapping)
        // Correct Answer: x
        // Distractor 1 (Sign Error on B): Added instead of subtracted
        let error1 = (c + b) / a
        // Distractor 2 (Sign Error on X): Flipped final parity
        let error2 = -x
        // Distractor 3 (Operation Error): Forgot to divide by a
        let error3 = c - b
        
        var rawOptions = [x, error1, error2, error3]
        
        // Failsafe: Ensure uniqueness if the random seeds create overlapping options
        while Set(rawOptions).count < 4 {
            rawOptions[3] += 1
        }
        
        rawOptions.shuffle()
        let correctIndex = rawOptions.firstIndex(of: x) ?? 0
        let stringOptions = rawOptions.map { String($0) }
        
        // 4. Construct Blocks for UniversalBlockEditorView
        let block = QuestionBlockModel(
            id: UUID().uuidString,
            type: "text",
            content: "Solve the following linear equation for $x$:\n\n\(equationLaTeX)"
        )
        
        // 5. Construct Dynamic Step-by-Step Feedback
        let feedback = """
        Step 1: Isolate the variable term by performing the inverse operation on \(b).
        $\(a)x = \(c) - (\(b))$
        $\(a)x = \(c - b)$
        
        Step 2: Divide both sides by \(a).
        $x = \(x)$
        """
        
        var question = Question(
            id: UUID().uuidString,
            correctOptionIndex: correctIndex,
            options: stringOptions,
            points: 10,
            questionText: "Solve for $x$: \(a)x \(signB) = \(c)",
            type: "multiple_choice",
            subject: subject,
            subtopic: subtopic,
            hint: "Isolate the variable $x$ by performing inverse operations on both sides of the equation.",
            feedback: feedback,
            testId: testId
        )
        
        // Inject blocks into the model
        question.updateWith(blocks: [block])
        
        return QuestionWrapper(question: question)
    }
}
