//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct LessonEditorView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    var lesson: Lesson?
    
    @Environment(\.dismiss) var dismiss
    
    @State private var lessonName: String = ""
    @State private var lessonDescription: String = ""
    @State private var lessonNumber: Int = 1
    @State private var pages: [Page] = []
    
    @State private var currentContent: String = ""
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        Form {
            Section("Lesson Data") {
                TextField("Lesson Name", text: $lessonName)
                TextField("Description", text: $lessonDescription)
                Stepper("Sequence Number: \(lessonNumber)", value: $lessonNumber, in: 1...100)
            }
            
            Section("Curriculum Pages") {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        Text("Page \(pages[index].pageNumber)").font(.headline)
                        Text(pages[index].content).lineLimit(2).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    pages.remove(atOffsets: indexSet)
                    // Re-index pages after deletion to maintain sequence integrity
                    for i in 0..<pages.count {
                        pages[i].pageNumber = i + 1
                    }
                }
            }
            
            Section("Create Content Block") {
                TextEditor(text: $currentContent)
                    .focused($isEditorFocused)
                    .frame(height: 200)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                
                HStack(spacing: 12) {
                    Button("Bold Text") { insertTag("[B]", "[/B]") }
                        .buttonStyle(.bordered)
                    
                    Button("Equation") { insertTag("[MATH]", "[/MATH]") }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    
                    Button("Line Graph") { insertTag("[GRAPH]", "[/GRAPH]") }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
                .padding(.vertical, 8)
                
                Button("Commit Page") {
                    let processed = processContent(currentContent)
                    // Added missing arguments: pageNumber and readyButtonDisplayed
                    let newPage = Page(
                        content: processed,
                        pageNumber: pages.count + 1,
                        readyButtonDisplayed: false
                    )
                    pages.append(newPage)
                    currentContent = ""
                    isEditorFocused = false
                }
                .disabled(currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            
            Button("Publish Full Lesson") {
                Task {
                    let newLesson = Lesson(id: lesson?.id, name: lessonName, description: lessonDescription, completed: false, lessonNumber: lessonNumber, pages: pages)
                    try? await viewModel.addLesson(to: subject, lesson: newLesson)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(lesson == nil ? "New Lesson" : "Edit Lesson")
        .onAppear {
            if let l = lesson {
                lessonName = l.name
                lessonDescription = l.description
                lessonNumber = l.lessonNumber
                pages = l.pages ?? []
            }
        }
    }
    
    private func insertTag(_ open: String, _ close: String) {
        currentContent += "\(open)\(close)"
    }
    
    private func processContent(_ text: String) -> String {
        var processed = text
        let regex = try! NSRegularExpression(pattern: "\\[MATH\\](.*?)\\[/MATH\\]", options: .dotMatchesLineSeparators)
        let matches = regex.matches(in: processed, range: NSRange(processed.startIndex..., in: processed))
        
        for match in matches.reversed() {
            if let range = Range(match.range(at: 1), in: processed) {
                let innerText = String(processed[range])
                let latex = parseToLatex(innerText)
                processed.replaceSubrange(range, with: latex)
            }
        }
        return processed
    }
    
    private func parseToLatex(_ input: String) -> String {
        var result = input
        result = result.replacingOccurrences(of: "\\^\\(([^)]+)\\)", with: "^{$1}", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\(([^)]+)\\)/\\(([^)]+)\\)", with: "\\\\frac{$1}{$2}", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*", with: "\\\\cdot ")
        return result
    }
}
