//
//  AdminView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/15/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

class AdminViewModel: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var lessons: [Lesson] = []
    @Published var showSubmissionSuccessAlert = false
    @Published var showingPageExistsWarning = false
    @Published var selectedSubject: String? {
        didSet {
            // Assuming you want to clear the lessons when the subject changes
            lessons.removeAll()
            if let subjectID = selectedSubject, !subjectID.isEmpty {
                fetchLessons(subjectID: subjectID)
            }
        }
    }

    // Setting db as internal or public as needed
    let db = Firestore.firestore()
        
    init() {
        fetchSubjects()
    }
    
    func fetchSubjects() {
        db.collection("Subjects").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("No documents in 'Subjects': \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            self?.subjects = documents.compactMap { queryDocumentSnapshot -> Subject? in
                try? queryDocumentSnapshot.data(as: Subject.self)
            }
        }
    }
    
    func fetchLessons(subjectID: String) {
        print("Attempting to fetch lessons for subjectID: \(subjectID)")
        db.collection("Subjects").document(subjectID).collection("Lessons")
            .getDocuments() { [weak self] (querySnapshot, error) in
                if let error = error {
                    print("Error getting lessons: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("No lessons found for subject \(subjectID)")
                    return
                }
                
                print("Found \(documents.count) lesson documents for subject \(subjectID).")

                let dispatchGroup = DispatchGroup()
                var fetchedLessons = [Lesson]()
                
                for document in documents {
                    print("Processing lesson document with ID: \(document.documentID)")
                    dispatchGroup.enter()
                    self?.fetchPages(forLessonID: document.documentID, inSubject: subjectID) { pages in
                        do {
                            var lesson = try document.data(as: Lesson.self)
                            lesson.id = document.documentID
                            lesson.pages = pages
                            fetchedLessons.append(lesson)
                            print("Successfully decoded lesson: \(lesson)")
                        } catch {
                            print("Failed to decode lesson: \(document.data()), error: \(error)")
                        }
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    if fetchedLessons.isEmpty {
                        print("No lessons could be decoded after fetching, check the data model and Firestore structure.")
                    } else {
                        print("Successfully fetched and decoded \(fetchedLessons.count) lessons with pages.")
                    }
                    self?.lessons = fetchedLessons.sorted { $0.name < $1.name }
                }
            }
    }

    private func fetchPages(forLessonID lessonID: String, inSubject subjectID: String, completion: @escaping ([Page]) -> Void) {
        db.collection("Subjects").document(subjectID).collection("Lessons").document(lessonID).collection("Pages")
            .getDocuments { (pageSnapshot, error) in
                if let error = error {
                    print("Error getting pages for lesson \(lessonID): \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let pages = pageSnapshot?.documents.compactMap { try? $0.data(as: Page.self) } ?? []
                completion(pages)
            }
    }
    
    func addPageToFirestore(selectedLessonID: String, pageNumber: Int, readyButtonDisplayed: Bool, content: String, example: String, explanation: String, graphics: String) {
            guard let subjectID = selectedSubject else {
                print("No subject selected")
                return
            }

            // Check if a page with the specified number already exists
            db.collection("Subjects").document(subjectID)
                .collection("Lessons").document(selectedLessonID)
                .collection("Pages").whereField("pageNumber", isEqualTo: pageNumber)
                .getDocuments { [weak self] (snapshot, error) in
                    if let error = error {
                        print("Error checking for existing page: \(error)")
                        return
                    }

                    if let snapshot = snapshot, !snapshot.documents.isEmpty {
                        // Page with this number already exists
                        self?.showingPageExistsWarning = true
                        return
                    }

                    let newPageData: [String: Any] = [
                        "pageNumber": pageNumber,
                        "readyButtonDisplayed": readyButtonDisplayed,
                        "content": content,
                        "example": example,
                        "explanation": explanation,
                        "graphics": graphics
                    ]

                    self?.db.collection("Subjects").document(subjectID)
                        .collection("Lessons").document(selectedLessonID)
                        .collection("Pages").addDocument(data: newPageData) { error in
                            if let error = error {
                                print("Error adding document: \(error)")
                            } else {
                                print("Document added successfully.")
                                self?.showSubmissionSuccessAlert = true
                            }
                        }
                }
        }
}

struct AdminView: View {
    @ObservedObject private var viewModel = AdminViewModel()
    @State private var selectedSubject = ""
    @State private var selectedLessonID: String?
    @State private var content = ""
    @State private var example = ""
    @State private var explanation = ""
    @State private var graphics = ""
    @State private var pageNumber: Int = 0
    @State private var readyButtonDisplayed = false
    
    //MARK: - BINDINGS FOR EXPONENT STYLING
    @State private var rawContent = ""
    @State private var rawExample = ""
    @State private var rawExplanation = ""
    @State private var rawGraphics = ""
    
    private var contentBinding: Binding<String> {
        Binding<String>(
            get: { self.rawContent },
            set: { self.rawContent = $0.replacingOccurrences(of: "^2", with: "²") }
        )
    }

    private var exampleBinding: Binding<String> {
        Binding<String>(
            get: { self.rawExample },
            set: { self.rawExample = $0.replacingOccurrences(of: "^2", with: "²") }
        )
    }

    private var explanationBinding: Binding<String> {
        Binding<String>(
            get: { self.rawExplanation },
            set: { self.rawExplanation = $0.replacingOccurrences(of: "^2", with: "²") }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Subject")) {
                    Picker("Subject", selection: $viewModel.selectedSubject) {
                        ForEach(viewModel.subjects) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }
                }

                Section(header: Text("Select Lesson")) {
                    Picker("Lesson", selection: $selectedLessonID) {
                        ForEach(viewModel.lessons) { lesson in
                            Text(lesson.name).tag(lesson.id as String?)
                        }
                    }
                    .onChange(of: viewModel.selectedSubject) { newSubject in
                        print("Subject changed to: \(newSubject ?? "none")")
                        self.selectedLessonID = nil // Ensure this line effectively resets the lesson selection
                    }
                }

                Section(header: Text("Page Details")) {
                    TextField("Page Number", value: $pageNumber, formatter: NumberFormatter())
                    Toggle(isOn: $readyButtonDisplayed) {
                        Text("Ready Button Displayed")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Content")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        TextEditor(text: contentBinding)
                            .frame(height: 200) // Set a fixed height
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        Text("Example")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        TextEditor(text: exampleBinding)
                            .frame(height: 200) // Set a fixed height
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        Text("Explanation")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        TextEditor(text: explanationBinding)
                            .frame(height: 200) // Set a fixed height
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        Text("Graphics")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        TextEditor(text: $graphics)
                            .frame(height: 200) // Set a fixed height
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 4)
                }

                Button("Add Page") {
                    if let selectedLesson = selectedLessonID {
                        // Use the rawContent, rawExample, and rawExplanation directly here
                        // because they are the processed strings with "^2" replaced with "²"
                        viewModel.addPageToFirestore(
                            selectedLessonID: selectedLesson,
                            pageNumber: pageNumber,
                            readyButtonDisplayed: readyButtonDisplayed,
                            content: rawContent, // Processed content
                            example: rawExample, // Processed example
                            explanation: rawExplanation, // Processed explanation
                            graphics: graphics // Unprocessed graphics URL
                        )
                    } else {
                        print("Please select a lesson first")
                    }
                }
                .disabled(selectedLessonID == nil)
            } //: FORM
            .navigationBarTitle("Admin Panel")
            // Use .onChange here to reset the selectedLessonID when the selectedSubject changes
            .onChange(of: viewModel.selectedSubject) { newSubject in
                print("Subject changed to: \(newSubject)")
                self.selectedLessonID = nil
            }
        } //: NAVIGATIONVIEW
        .alert("Page Already Exists", isPresented: $viewModel.showingPageExistsWarning) {
            Button("OK") { }
        } message: {
            Text("A page with this number already exists in the selected lesson. Please use a different page number.")
        }
        .alert("Success", isPresented: $viewModel.showSubmissionSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("The page has been successfully added.")
        }
        .background(TapGestureView(action: hideKeyboard))
    }
}

// To click out of the text box
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct TapGestureView: View {
    var action: () -> Void
    
    var body: some View {
        Color.clear
            .contentShape(Rectangle()) // Make sure the tap gesture is recognized across the entire area
            .onTapGesture(perform: action)
    }
}

#Preview {
    AdminView()
}



