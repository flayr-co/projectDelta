//
//  SuperAdminConsoleView.swift
//  ProjectDelta
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
        collectionPath = [collection]
        selectedDocument = nil
        await fetchDocuments()
    }
    
    func drillDown(docId: String, subcollection: String) async {
        guard !subcollection.isEmpty else { return }
        collectionPath.append(contentsOf: [docId, subcollection])
        selectedDocument = nil
        await fetchDocuments()
    }
    
    func navigateBack() async {
        guard collectionPath.count >= 3 else { return }
        collectionPath.removeLast(2)
        selectedDocument = nil
        await fetchDocuments()
    }
    
    func fetchDocuments() async {
        let path = currentCollectionPathString
        guard !path.isEmpty else { self.documents.removeAll(); return }
        
        isFetching = true
        do {
            let snapshot = try await db.collection(path).limit(to: 100).getDocuments()
            self.documents = snapshot.documents.map { RawFirestoreDocument(id: $0.documentID, data: $0.data()) }
        } catch {
            print("Fetch Error: \(error.localizedDescription)")
        }
        isFetching = false
    }
    
    func saveDocumentEdits() async {
        let path = currentCollectionPathString
        guard !path.isEmpty, let doc = selectedDocument else { return }
        
        isSaving = true
        do {
            try await db.collection(path).document(doc.id).setData(doc.data, merge: false)
            if let index = documents.firstIndex(where: { $0.id == doc.id }) { documents[index] = doc }
        } catch {
            print("Save Error: \(error.localizedDescription)")
        }
        isSaving = false
    }
    
    func deleteDocument(id: String) async {
        let path = currentCollectionPathString
        guard !path.isEmpty else { return }
        
        do {
            try await db.collection(path).document(id).delete()
            withAnimation {
                documents.removeAll(where: { $0.id == id })
                if selectedDocument?.id == id { selectedDocument = nil }
            }
        } catch {
            print("Delete Error: \(error.localizedDescription)")
        }
    }
    
    func createNewDocument(with id: String) async {
        let path = currentCollectionPathString
        guard !path.isEmpty, !id.isEmpty else { return }
        
        isSaving = true
        do {
            try await db.collection(path).document(id).setData(["createdAt": FieldValue.serverTimestamp()])
            let newDoc = RawFirestoreDocument(id: id, data: ["createdAt": "Just Now (Timestamp)"])
            withAnimation {
                documents.insert(newDoc, at: 0)
                selectedDocument = newDoc
            }
        } catch {
            print("Create Error: \(error.localizedDescription)")
        }
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
    
    // UI Constants
    private let accentGradient = LinearGradient(colors: [Color(red: 0.12, green: 0.65, blue: 0.65), Color(red: 0.08, green: 0.5, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    private let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    // Explicitly manage visibility to help macOS rendering
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar Column
            List(viewModel.rootCollections, id: \.self, selection: $selectedRoot) { collection in
                NavigationLink(value: collection) {
                    HStack(spacing: 12) {
                        Image(systemName: iconForCollection(collection))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(primaryTeal)
                            .frame(width: 24)
                        
                        Text(collection)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(selectedRoot == collection ? primaryTeal.opacity(0.15) : Color.clear)
            }
            .navigationTitle("Database")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
            // By defining containerBackground with ultraThinMaterial on macOS, we force the
            // window chrome to draw the sidebar glass all the way up to the top window edge,
            // preventing the cutoff bug.
            .containerBackground(.ultraThinMaterial, for: .window)
            #endif
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onChange(of: selectedRoot) { _, newValue in
                if let root = newValue {
                    Task { await viewModel.selectRootCollection(root) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } content: {
            // MARK: - Content Column
            Group {
                if viewModel.isFetching {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(primaryTeal)
                        Text("Querying Cluster...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.documents.isEmpty {
                    ContentUnavailableView {
                        Label("No Documents", systemImage: "tray")
                    } description: {
                        Text("This collection is currently empty.")
                    }
                } else {
                    List(viewModel.documents, selection: $viewModel.selectedDocument) { doc in
                        NavigationLink(value: doc) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.secondary.opacity(0.5))
                                Text(doc.id)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(viewModel.selectedDocument?.id == doc.id ? primaryTeal.opacity(0.15) : Color.clear)
                        .contextMenu {
                            Button(role: .destructive, action: {
                                docToDelete = doc.id
                                showDeleteAlert = true
                            }) {
                                Label("Eradicate", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(viewModel.collectionPath.last ?? "Collections")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
            .background(Color.platformSecondarySystemBackground)
            #endif
            .task(id: viewModel.currentCollectionPathString) {
                await viewModel.fetchDocuments()
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    if viewModel.collectionPath.count > 1 {
                        Button(action: { Task { await viewModel.navigateBack() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .fontWeight(.medium)
                            .foregroundStyle(primaryTeal)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showNewDocAlert = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .disabled(viewModel.collectionPath.isEmpty)
                    .tint(primaryTeal)
                }
            }
        } detail: {
            // MARK: - Detail Column
            Group {
                if let doc = viewModel.selectedDocument {
                    DocumentEditorPanel(
                        document: Binding(get: { doc }, set: { viewModel.selectedDocument = $0 }),
                        isSaving: viewModel.isSaving,
                        suggestedSubcollections: viewModel.getSuggestedSubcollections(),
                        onSave: { Task { await viewModel.saveDocumentEdits() } },
                        onDrillDown: { sub in Task { await viewModel.drillDown(docId: doc.id, subcollection: sub) } }
                    )
                } else {
                    ContentUnavailableView {
                        Label("Inspector Node", systemImage: "server.rack")
                    } description: {
                        Text("Select a document from the hierarchy to view or mutate its raw JSON payload.")
                    }
                }
            }
            #if os(macOS)
            .background(Color.platformSystemBackground)
            #endif
        }
        .frame(minWidth: 1000, minHeight: 700)
        .preferredColorScheme(.dark)
        // ALERTS
        .alert("Eradicate Document", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { docToDelete = nil }
            Button("Confirm Deletion", role: .destructive) {
                if let id = docToDelete { Task { await viewModel.deleteDocument(id: id) } }
            }
        } message: {
            Text("This action is irreversible and will completely destroy the document and all nested fields.")
        }
        .alert("Initialize Document", isPresented: $showNewDocAlert) {
            TextField("Document ID (Leave blank for Auto-ID)", text: $newDocId)
            Button("Cancel", role: .cancel) { newDocId = "" }
            Button("Create") {
                let idToUse = newDocId.isEmpty ? UUID().uuidString : newDocId
                Task { await viewModel.createNewDocument(with: idToUse); newDocId = "" }
            }
        }
    }
    
    private func iconForCollection(_ name: String) -> String {
        switch name {
        case "Users": return "person.2.fill"
        case "Subjects": return "books.vertical.fill"
        case "questions": return "questionmark.folder.fill"
        case "quizSnapshots": return "camera.macro"
        case "UserProgress": return "chart.xyaxis.line"
        default: return "folder.fill"
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
    @State private var manualSubcollectionInput: String = ""
    
    private let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Document Inspector")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("ID: \(document.id)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 24)
                
                // Navigation Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "folder.tree.fill")
                            .foregroundStyle(primaryTeal)
                        Text("Sub-Collections")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    if !suggestedSubcollections.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(suggestedSubcollections, id: \.self) { sub in
                                    Button(action: { onDrillDown(sub) }) {
                                        Text(sub)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(primaryTeal.opacity(0.15))
                                            .foregroundStyle(primaryTeal)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Manual subcollection path...", text: $manualSubcollectionInput)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                        
                        Button(action: { onDrillDown(manualSubcollectionInput) }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(primaryTeal)
                        }
                        .buttonStyle(.plain)
                        .disabled(manualSubcollectionInput.isEmpty)
                    }
                }
                .padding()
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Fields Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundStyle(Color.orange)
                        Text("Mutate Fields")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        ForEach(document.data.keys.sorted(), id: \.self) { key in
                            HStack(alignment: .top) {
                                Text(key)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 140, alignment: .leading)
                                    .padding(.top, 8)
                                
                                TextField("Value", text: Binding(
                                    get: { "\(document.data[key] ?? "")" },
                                    set: { document.data[key] = $0 }
                                ), axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...10)
                                .padding(10)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onSave) {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white)
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "server.rack")
                    }
                    Text("Commit Payload")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(primaryTeal)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: primaryTeal.opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(
                LinearGradient(colors: [Color.platformSystemBackground.opacity(0), Color.platformSystemBackground], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}
