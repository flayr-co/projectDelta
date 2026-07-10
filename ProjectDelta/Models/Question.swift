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
    var id: String
    var type: String
    var content: String
    var graphType: String?
    
    init(id: String = UUID().uuidString, type: String, content: String, graphType: String? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.graphType = graphType
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, content, graphType
    }
    
    // Indestructible Decoder with Auto-Healing Math Logic
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Safely extract ID whether it's a String, a strict UUID, or completely missing
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else if let idUUID = try? container.decode(UUID.self, forKey: .id) {
            self.id = idUUID.uuidString
        } else {
            self.id = UUID().uuidString
        }
        
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? QuestionBlockType.text.rawValue
        
        var rawContent = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        
        // Auto-Heal stripped backslashes from Firestore corruption
        if self.type == QuestionBlockType.math.rawValue {
            let commands = ["frac", "sqrt", "sin", "cos", "tan", "csc", "sec", "cot", "ln", "log", "pi", "theta", "alpha", "beta", "int", "sum", "infty", "leq", "geq", "neq", "approx", "times", "div", "pm"]
            for cmd in commands {
                rawContent = rawContent.replacingOccurrences(of: "(?<!\\\\)\(cmd)", with: "\\\\\(cmd)", options: .regularExpression)
            }
        }
        self.content = rawContent
        self.graphType = try container.decodeIfPresent(String.self, forKey: .graphType)
    }
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
        // Intercept broken JSON strings and display a clean admin warning instead of crashing UI
        if questionText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            return [QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: "⚠️ Rendering Error: Data corrupted. Please open and re-save this question in the Admin portal to automatically heal the JSON.")]
        }
        return [QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: questionText)]
    }
    
    mutating func updateWith(blocks: [QuestionBlockModel]) {
        // Save the raw blocks exactly as the user typed them.
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
