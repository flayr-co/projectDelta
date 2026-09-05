import Foundation

struct RatiosAndProportionsTemplate: QuestionTemplate {
    let subject = "Pre-Algebra" // Verify this perfectly matches your Subject name in the database
    let subtopic = "Ratios, Rates, & Proportions" // Fixed: Changed "and" to "&" to match the UI
    
    func generate(testId: String?) -> QuestionWrapper {
        // 1. Generate clean proportional values
        let a = Int.random(in: 2...9)
        let b = Int.random(in: 2...12)
        let multiplier = Int.random(in: 2...10)
        let c = a * multiplier
        let x = b * multiplier
        
        let equationLaTeX = "\\frac{\(a)}{\(b)} = \\frac{\(c)}{x}"
        
        // 2. Generate common misconception distractors
        let error1 = c * a // Multiplied numerators
        let error2 = x + a // Added instead of scaled
        let error3 = (c * b) / a + 1 // Off by one error
        
        var rawOptions = [x, error1, error2, error3]
        while Set(rawOptions).count < 4 { rawOptions[3] += 1 } // Ensure uniqueness
        rawOptions.shuffle()
        
        let correctIndex = rawOptions.firstIndex(of: x) ?? 0
        let stringOptions = rawOptions.map { String($0) }
        
        let block = QuestionBlockModel(
            id: UUID().uuidString,
            type: "text",
            content: "Solve for the unknown value $x$ in the given proportion:\n\n[MATH]\n\(equationLaTeX)\n[/MATH]"
        )
        
        let feedback = """
        Use cross-multiplication to solve:
        $\(a) \\times x = \(b) \\times \(c)$
        $\(a)x = \(b * c)$
        $x = \(x)$
        """
        
        var question = Question(
            id: UUID().uuidString,
            correctOptionIndex: correctIndex,
            options: stringOptions,
            points: 10,
            questionText: "Solve for x in the proportion \(a)/\(b) = \(c)/x",
            type: "multiple_choice",
            subject: subject,
            subtopic: subtopic,
            hint: "Cross-multiply the numerator of one fraction with the denominator of the other.",
            feedback: feedback,
            testId: testId
        )
        
        question.updateWith(blocks: [block])
        return QuestionWrapper(question: question)
    }
}
