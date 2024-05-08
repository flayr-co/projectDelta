//
//  OpenAIAdminView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/5/24.
//

import SwiftUI
import Alamofire

struct OpenAIAdminView: View {
    @ObservedObject private var viewModel = OpenAIAdminViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Subject")) {
                    Picker("Select a Subject", selection: $viewModel.selectedSubject) {
                        ForEach(viewModel.subjects) { subject in
                            Text(subject.name).tag(subject as Subject?)
                        }
                    }
                    .onChange(of: viewModel.selectedSubject) { newValue in
                        Task {
                            if let newSubject = newValue {
                                await viewModel.fetchLessons(forSubject: newSubject)
                            } else {
                                print("No subject selected, cannot fetch lessons")
                            }
                        }
                    }
                }
                
                Section(header: Text("Select Lesson")) {
                    Picker("Select a Lesson", selection: $viewModel.selectedLesson) {
                        ForEach(viewModel.lessons) { lesson in
                            Text(lesson.name).tag(lesson as Lesson?)
                        }
                    }
                }
                
                Section {
                    Button("Generate New Page") {
                        print("Generate New Page button pressed.")
                        viewModel.generateNewPageContent()
                    }
                    .disabled(viewModel.selectedSubject == nil || viewModel.selectedLesson == nil)
                }
                
                Section(header: Text("Generated Page")) {
                    if let page = viewModel.latestPage {
                        Text(page.content)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No page generated yet")
                            .padding()
                    }
                }
            }
            .navigationBarTitle("Admin Panel")
        }
        .onAppear {
            Task {
                await viewModel.fetchSubjects()
            }
        }
    }
}

#Preview {
    OpenAIAdminView()
}
