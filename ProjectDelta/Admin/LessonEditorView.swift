//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct LessonEditorView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    var lesson: Lesson
    
    @State private var pageNumber: Int = 1
    @State private var contentType: ContentType = .text
    @State private var content: String = ""
    @State private var latexEquation: String = ""
    @State private var graphData: String = ""
    
    @State private var selectedSubjectArea: SubjectArea = .algebra
    
    enum ContentType: String, CaseIterable {
        case text = "Text", latex = "LaTeX", graph = "Graph"
    }
    
    var body: some View {
        Form {
            Section("Subject Context") {
                Picker("Subject", selection: $selectedSubjectArea) {
                    ForEach(SubjectArea.allCases) { area in
                        Text(area.rawValue).tag(area)
                    }
                }
            }
            
            Section("Page Order") {
                Stepper("Page: \(pageNumber)", value: $pageNumber)
                Picker("Type", selection: $contentType) {
                    ForEach(ContentType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Content") {
                if contentType == .text {
                    TextEditor(text: $content).frame(height: 150)
                } else if contentType == .latex {
                    TextField("LaTeX String", text: $latexEquation)
                } else {
                    TextField("Slope, Intercept (m, b)", text: $graphData)
                }
            }
            
            Button("Add Page") {
                let finalGraphics = contentType == .graph ? "graph:\(graphData)" : (contentType == .latex ? "latex:\(latexEquation)" : nil)
                let newPage = Page(content: content, pageNumber: pageNumber, readyButtonDisplayed: true, graphics: finalGraphics)
                
                Task {
                    let idToSave = subject.id ?? selectedSubjectArea.rawValue
                    await viewModel.savePage(subjectId: idToSave, lessonId: lesson.id ?? "", page: newPage)
                    pageNumber += 1; content = ""; latexEquation = ""; graphData = ""
                }
            }
        }
        .navigationTitle("Edit Lesson")
        .onAppear {
            if let initialArea = SubjectArea(rawValue: subject.name) ?? SubjectArea(rawValue: subject.subjectArea.rawValue) {
                selectedSubjectArea = initialArea
            }
        }
    }
}
