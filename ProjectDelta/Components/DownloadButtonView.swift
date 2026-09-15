//
//  DownloadButtonView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/14/26.
//
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
    var isDownloaded: Bool {
        switch itemType {
        case .lesson:
            return OfflineStorageManager.shared.downloadedLessonIDs.contains(itemID)
        case .test:
            return OfflineStorageManager.shared.downloadedTestIDs.contains(itemID)
        }
    }
    
    enum ItemType {
        case lesson, test
    }
    
    var body: some View {
        Button(action: {
            if isDownloaded {
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
                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDownloaded ? Color.green : themeColor.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 32, height: 32)
            .background(isDownloaded ? Color.green.opacity(0.1) : themeColor.opacity(0.08), in: .circle)
        }
        .disabled(isDownloading)
        .buttonStyle(.plain)
    }
    
    private func performDownload() {
        isDownloading = true
        Task {
            do {
                try await onDownload()
            } catch {
                print("Download failed: \(error.localizedDescription)")
            }
            // Add an artificial delay to prevent UI flashing if the payload writes too fast
            try? await Task.sleep(for: .seconds(0.5))
            isDownloading = false
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
        } catch {
            print("Deletion failed: \(error.localizedDescription)")
        }
    }
}
