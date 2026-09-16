//
//  DownloadButtonView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/14/26.
//
//  DownloadButtonView.swift
//  ProjectDelta
//

import SwiftUI

struct DownloadButtonView: View {
    let itemID: String
    let itemType: ItemType
    var themeColor: Color = .blue
    let onDownload: () async throws -> Void
    
    @State private var isDownloading = false
    @State private var isDownloadedLocally = false // Forces SwiftUI to track and redraw this state
    
    enum ItemType {
        case lesson, test
    }
    
    var body: some View {
        Button(action: {
            if isDownloadedLocally {
                removeOfflineData()
            } else {
                performDownload()
            }
        }) {
            ZStack {
                if isDownloading {
                    ProgressView()
                        .tint(themeColor)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isDownloadedLocally ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDownloadedLocally ? Color.green : themeColor.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 32, height: 32)
            .background(isDownloadedLocally ? Color.green.opacity(0.1) : themeColor.opacity(0.08), in: .circle)
        }
        .disabled(isDownloading)
        .buttonStyle(.plain)
        .onAppear {
            syncStateWithManager()
        }
    }
    
    private func syncStateWithManager() {
        switch itemType {
        case .lesson:
            isDownloadedLocally = OfflineStorageManager.shared.downloadedLessonIDs.contains(itemID)
        case .test:
            isDownloadedLocally = OfflineStorageManager.shared.downloadedTestIDs.contains(itemID)
        }
    }
    
    private func performDownload() {
        isDownloading = true
        Task {
            do {
                try await onDownload()
                
                await MainActor.run {
                    isDownloadedLocally = true
                }
            } catch {
                print("Download failed: \(error.localizedDescription)")
            }
            
            // Add an artificial delay to prevent UI flashing if the payload writes too fast
            try? await Task.sleep(for: .seconds(0.5))
            
            await MainActor.run {
                isDownloading = false
            }
        }
    }
    
    private func removeOfflineData() {
        do {
            switch itemType {
            case .lesson:
                try OfflineStorageManager.shared.removeLesson(id: itemID)
            case .test:
                try OfflineStorageManager.shared.removeTest(id: itemID)
            }
            isDownloadedLocally = false
        } catch {
            print("Deletion failed: \(error.localizedDescription)")
        }
    }
}
