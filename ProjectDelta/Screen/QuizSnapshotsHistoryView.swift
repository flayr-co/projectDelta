//
//  QuizSnapshotsHistoryView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/13/26.
//


//
//  QuizSnapshotsHistoryView.swift
//  ProjectDelta
//
//  Created by Jake Meissner.
//

import SwiftUI
import FirebaseFirestore

struct QuizSnapshotsHistoryView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var snapshots: [QuizSnapshot] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading progress...")
            } else if snapshots.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No quiz snapshots yet.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(snapshots.sorted(by: { $0.dateTaken > $1.dateTaken })) { snapshot in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(snapshot.subtopic.isEmpty ? snapshot.subjectId : snapshot.subtopic)
                                .font(.headline)
                                .foregroundColor(.primary)
                            HStack {
                                Text("Score: \(snapshot.score) / \(snapshot.totalQuestions)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.cyan)
                                Spacer()
                                Text(snapshot.dateTaken.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(colorScheme == .dark ? Color.customDarkGray : Color.white)
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Your Progress")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await fetchSnapshots()
        }
    }
    
    private func fetchSnapshots() async {
        guard let userId = viewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            let db = Firestore.firestore()
            let query = db.collection("quizSnapshots")
                .whereField("userId", isEqualTo: userId)
            
            let querySnapshot = try await query.getDocuments()
            
            var fetched: [QuizSnapshot] = []
            for document in querySnapshot.documents {
                if let snap = try? document.data(as: QuizSnapshot.self) {
                    fetched.append(snap)
                }
            }
            self.snapshots = fetched
        } catch {
            print("Error fetching snapshots: \(error)")
        }
        isLoading = false
    }
}
