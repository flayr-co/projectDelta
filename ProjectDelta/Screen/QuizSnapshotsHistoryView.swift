//
//  QuizSnapshotsHistoryView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/13/26.
//

import SwiftUI
import FirebaseFirestore

struct QuizSnapshotsHistoryView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var snapshots: [QuizSnapshot] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .navigationTitle("Your Progress")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await fetchSnapshots()
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack {
            Color.platformSystemGroupedBackground
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading progress...")
            } else if snapshots.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No quiz snapshots yet.")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    let desktopColumns = [
                        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 24)
                    ]
                    
                    LazyVGrid(columns: desktopColumns, spacing: 24) {
                        ForEach(snapshots.sorted(by: { $0.dateTaken > $1.dateTaken })) { snapshot in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(snapshot.subtopic.isEmpty ? snapshot.subjectId : snapshot.subtopic)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Score")
                                            .font(.system(.caption, design: .rounded, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text("\(snapshot.score) / \(snapshot.totalQuestions)")
                                            .font(.system(.title2, design: .rounded, weight: .heavy))
                                            .foregroundColor(.cyan)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Date")
                                            .font(.system(.caption, design: .rounded, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text(snapshot.dateTaken.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(.body, design: .rounded, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(24)
                            .background(Color.platformSystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        }
                    }
                    .padding(40)
                    .frame(maxWidth: 1200)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
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
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
    #endif
    
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
