//
//  Question.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/17/23.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore

struct Question: Identifiable, Codable {
    @DocumentID var id: String?
    var correctOptionIndex: Int
    var options: [String]
    var points: Int
    var questionText: String
    var type: String
    var subject: String
    var subtopic: String?
    var hint: String?
    var feedback: String?
    var testId: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "correctOptionIndex": correctOptionIndex,
            "options": options,
            "points": points,
            "questionText": questionText,
            "type": type,
            "subject": subject
        ]

        if let subtopic = subtopic {
            dict["subtopic"] = subtopic
        }
        
        if let hint = hint {
            dict["hint"] = hint
        }
        
        if let feedback = feedback {
            dict["feedback"] = feedback
        }
        
        if let testId = testId {
            dict["testId"] = testId
        }
        
        return dict
    }
}

// MARK: - Plain Text Math to LaTeX Converter
extension String {
    var parsedMathToLatex: String {
        var str = self
        
        // 1. Standard formatting & Symbol replacement
        let replacements: [String: String] = [
            "*": " \\times ",
            "==": " = ",
            "!=": " \\neq ",
            "<=": " \\leq ",
            ">=": " \\geq ",
            "≤": " \\leq ",
            "≥": " \\geq ",
            "≠": " \\neq ",
            "≈": " \\approx ",
            "π": " \\pi ",
            "θ": " \\theta ",
            "α": " \\alpha ",
            "β": " \\beta ",
            "∫": " \\int ",
            "∑": " \\sum ",
            "∞": " \\infty ",
            "°": "^{\\circ}"
        ]
        
        for (key, value) in replacements {
            str = str.replacingOccurrences(of: key, with: value)
        }
        
        // 2. Trig & Log Functions (converts "ln(" to "\ln(")
        // Note: Using a space before the slash prevents replacing already formatted LaTeX if re-parsed
        let functions = ["sin", "cos", "tan", "csc", "sec", "cot", "ln", "log"]
        for fn in functions {
            // Only replace if it doesn't already have a backslash
            str = str.replacingOccurrences(of: "(?<!\\\\)\(fn)\\(", with: "\\\\\(fn)(", options: .regularExpression)
        }
        
        // 3. Square Root Parser: converts "√(x+2)" into "\sqrt{x+2}"
        if let regex = try? NSRegularExpression(pattern: "√\\((.*?)\\)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "\\\\sqrt{$1}")
        }
        
        // 4. Exponent Parser with parentheses: converts "x^(2y)" into "x^{2y}"
        if let regex = try? NSRegularExpression(pattern: "\\^\\((.*?)\\)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "^{$1}")
        }
        
        // 5. Smart Fraction Parser: converts "1/2" or "x / y" into "\frac{1}{2}"
        if let regex = try? NSRegularExpression(pattern: "([a-zA-Z0-9]+)\\s*/\\s*([a-zA-Z0-9]+)") {
            str = regex.stringByReplacingMatches(in: str, range: NSRange(str.startIndex..., in: str), withTemplate: "\\\\frac{$1}{$2}")
        }
        
        return str
    }
}

// MARK: - Block Editor Models & Extensions

enum QuestionBlockType: String, CaseIterable {
    case text = "Text"
    case math = "Equation"
    case graph = "Graph"
}

enum QuestionGraphType: String, CaseIterable {
    case equation = "Function (y = f(x))"
    case points = "Points Data"
}

struct QuestionBlockModel: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: String
    var content: String
    var graphType: String?
}

extension Question {
    var parsedBlocks: [QuestionBlockModel] {
        if let data = questionText.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([QuestionBlockModel].self, from: data) {
            return decoded
        }
        if questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return [QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: questionText)]
    }
    
    mutating func updateWith(blocks: [QuestionBlockModel]) {
        // Save the raw blocks exactly as the user typed them.
        // We no longer permanently overwrite the raw content with parsed LaTeX here.
        if let data = try? JSONEncoder().encode(blocks),
           let jsonString = String(data: data, encoding: .utf8) {
            self.questionText = jsonString
        } else {
            self.questionText = blocks.map { $0.content }.joined(separator: "\n")
        }
    }
}

// MARK: - Wrapper to Prevent SwiftUI Index Crashes
struct QuestionWrapper: Identifiable {
    let id = UUID()
    var question: Question
}
