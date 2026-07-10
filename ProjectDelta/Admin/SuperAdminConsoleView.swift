//
//  SuperAdminConsoleView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 7/10/26.
//

import SwiftUI
import FirebaseFirestore
import Observation

// MARK: - Core Data Wrapper
struct RawFirestoreDocument: Identifiable, Hashable {
    let id: String
    var data: [String: Any]
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RawFirestoreDocument, rhs: RawFirestoreDocument) -> Bool { lhs.id == rhs.id }
}

// MARK: - View Model
@MainActor
@Observable
class SuperAdminViewModel {
    let rootCollections: [String] = ["Users", "Subjects", "questions", "quizSnapshots", "UserProgress"]
    var collectionPath: [String] = []
    var currentCollectionPathString: String { collectionPath.joined(separator: "/") }
    var documents: [RawFirestoreDocument] = []
    var selectedDocument: RawFirestoreDocument?
    var isFetching: Bool = false
    var isSaving: Bool = false
    private let db = Firestore.firestore()
    
    func selectRootCollection(_ collection: String) async {
        collectionPath = [collection]; selectedDocument = nil; await fetchDocuments()
    }
    
    func drillDown(docId: String, subcollection: String) async {
        guard !subcollection.isEmpty else { return }
        collectionPath.append(contentsOf: [docId, subcollection]); selectedDocument = nil; await fetchDocuments()
    }
    
    func navigateBack() async {
        guard collectionPath.count >= 3 else { return }
        collectionPath.removeLast(2); selectedDocument = nil; await fetchDocuments()
    }
    
    func fetchDocuments() async {
        let path = currentCollectionPathString
        guard !path.isEmpty else { self.documents.removeAll(); return }
        isFetching = true
        do {
            let snapshot = try await db.collection(path).limit(to: 100).getDocuments()
            self.documents = snapshot.documents.map { RawFirestoreDocument(id: $0.documentID, data: $0.data()) }
        } catch { print("Fetch Error: \(error.localizedDescription)") }
        isFetching = false
    }
    
    func saveDocumentEdits() async {
        let path = currentCollectionPathString
        guard !path.isEmpty, let doc = selectedDocument else { return }
        isSaving = true
        do {
            try await db.collection(path).document(doc.id).setData(doc.data, merge: false)
            if let index = documents.firstIndex(where: { $0.id == doc.id }) { documents[index] = doc }
        } catch { print("Save Error: \(error.localizedDescription)") }
        isSaving = false
    }
    
    func deleteDocument(id: String) async {
        let path = currentCollectionPathString
        guard !path.isEmpty else { return }
        do {
            try await db.collection(path).document(id).delete()
            withAnimation { documents.removeAll(where: { $0.id == id }); if selectedDocument?.id == id { selectedDocument = nil } }
        } catch { print("Delete Error: \(error.localizedDescription)") }
    }
    
    func createNewDocument(with id: String) async {
        let path = currentCollectionPathString
        guard !path.isEmpty, !id.isEmpty else { return }
        isSaving = true
        do {
            try await db.collection(path).document(id).setData(["createdAt": FieldValue.serverTimestamp()])
            let newDoc = RawFirestoreDocument(id: id, data: ["createdAt": "Just Now (Timestamp)"])
            withAnimation { documents.insert(newDoc, at: 0); selectedDocument = newDoc }
        } catch { print("Create Error: \(error.localizedDescription)") }
        isSaving = false
    }
    
    func getSuggestedSubcollections() -> [String] {
        guard let currentTarget = collectionPath.last else { return [] }
        switch currentTarget {
        case "Subjects": return ["Lessons", "Tests"]
        case "Tests": return ["Questions"]
        case "UserProgress": return ["History"]
        default: return []
        }
    }
}

// MARK: - Main UI View
struct SuperAdminConsoleView: View {
    @State private var viewModel = SuperAdminViewModel()
    @State private var selectedRoot: String? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var docToDelete: String? = nil
    @State private var showNewDocAlert: Bool = false
    @State private var newDocId: String = ""
    @Environment(\.dismiss) var dismiss
    
    private let accentTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.rootCollections, id: \.self, selection: $selectedRoot) { collection in
                Text(collection).font(.headline).padding(.vertical, 4)
            }
            .onChange(of: selectedRoot) { _, newValue in
                if let root = newValue { Task { await viewModel.selectRootCollection(root) } }
            }
            .navigationTitle("Flayr LLC Console")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Exit") { dismiss() }.foregroundStyle(accentTeal) } }
        } content: {
            Group {
                if viewModel.isFetching { ProgressView("Querying...") }
                else if viewModel.documents.isEmpty { ContentUnavailableView("No Documents", systemImage: "tray") }
                else {
                    List(viewModel.documents, selection: $viewModel.selectedDocument) { doc in
                        NavigationLink(value: doc) {
                            VStack(alignment: .leading) {
                                Text(doc.id).font(.system(.body, design: .monospaced)).fontWeight(.bold)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { docToDelete = doc.id; showDeleteAlert = true } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.collectionPath.last ?? "Documents")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .navigation) { if viewModel.collectionPath.count > 1 { backButton } }
                #else
                ToolbarItem(placement: .navigationBarLeading) { if viewModel.collectionPath.count > 1 { backButton } }
                #endif
                ToolbarItem(placement: .primaryAction) { Button(action: { showNewDocAlert = true }) { Image(systemName: "plus") }.disabled(viewModel.collectionPath.isEmpty) }
            }
        } detail: {
            if let doc = viewModel.selectedDocument {
                DocumentEditorPanel(document: Binding(get: { doc }, set: { viewModel.selectedDocument = $0 }), isSaving: viewModel.isSaving, suggestedSubcollections: viewModel.getSuggestedSubcollections(), onSave: { Task { await viewModel.saveDocumentEdits() } }, onDrillDown: { sub in Task { await viewModel.drillDown(docId: doc.id, subcollection: sub) } })
            } else { ContentUnavailableView("Select a Document", systemImage: "server.rack") }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Document", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { docToDelete = nil }
            Button("Delete", role: .destructive) { if let id = docToDelete { Task { await viewModel.deleteDocument(id: id) } } }
        } message: { Text("Permanently eradicate from Firestore?") }
        .alert("New Document", isPresented: $showNewDocAlert) {
            TextField("Document ID (Leave blank for Auto-ID)", text: $newDocId)
            Button("Cancel", role: .cancel) { newDocId = "" }
            Button("Create") { let idToUse = newDocId.isEmpty ? UUID().uuidString : newDocId; Task { await viewModel.createNewDocument(with: idToUse); newDocId = "" } }
        }
    }
    
    private var backButton: some View {
        Button(action: { Task { await viewModel.navigateBack() } }) {
            HStack { Image(systemName: "chevron.left"); Text("Back") }.fontWeight(.bold).foregroundStyle(accentTeal)
        }
    }
}

// MARK: - Document Editor
struct DocumentEditorPanel: View {
    @Binding var document: RawFirestoreDocument
    var isSaving: Bool
    var suggestedSubcollections: [String]
    var onSave: () -> Void
    var onDrillDown: (String) -> Void
    @State private var newFieldKey: String = ""; @State private var newFieldValue: String = ""; @State private var showAddField: Bool = false; @State private var manualSubcollectionInput: String = ""
    let accentEmerald = Color(red: 0.18, green: 0.77, blue: 0.45)
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Subcollections")) {
                    ForEach(suggestedSubcollections, id: \.self) { sub in Button(sub) { onDrillDown(sub) } }
                    HStack { TextField("Path...", text: $manualSubcollectionInput).textFieldStyle(.roundedBorder); Button("Go") { onDrillDown(manualSubcollectionInput) } }
                }
                Section(header: Text("Raw Data")) {
                    ForEach(document.data.keys.sorted(), id: \.self) { key in
                        DynamicFieldRow(key: key, value: document.data[key], onUpdate: { val in document.data[key] = val }, onDelete: { document.data.removeValue(forKey: key) })
                    }
                    Button("Add Field") { showAddField.toggle() }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            Button("Commit Mutation") { onSave() }.padding().disabled(isSaving)
        }
    }
}

// MARK: - Dynamic Field
struct DynamicFieldRow: View {
    let key: String; let value: Any?; var onUpdate: (Any) -> Void; var onDelete: () -> Void
    var body: some View {
        HStack {
            Text(key).frame(width: 100, alignment: .leading)
            if let str = value as? String { TextField("Value", text: Binding(get: { str }, set: { onUpdate($0) })) }
            else { Text("Complex Data").foregroundStyle(.secondary) }
        }
        .swipeActions { Button("Delete", role: .destructive, action: onDelete) }
    }
}
