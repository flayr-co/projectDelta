//
//  OfflineStorageManager.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/14/26.
//


//
//  OfflineStorageManager.swift
//  ProjectDelta
//

import Foundation
import Observation

@MainActor
@Observable
class OfflineStorageManager {
    static let shared = OfflineStorageManager()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Published sets for real-time UI updates (e.g. flipping a cloud icon to a checkmark)
    var downloadedLessonIDs: Set<String> = []
    var downloadedTestIDs: Set<String> = []
    
    private init() {
        refreshDownloadedStates()
    }
    
    // MARK: - Directory Management
    
    private var lessonsDirectory: URL {
        let url = URL.documentsDirectory.appending(path: "OfflineLessons", directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: url.path()) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    private var testsDirectory: URL {
        let url = URL.documentsDirectory.appending(path: "OfflineTests", directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: url.path()) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    // MARK: - State Syncing
    
    private func refreshDownloadedStates() {
        if let lessonUrls = try? fileManager.contentsOfDirectory(at: lessonsDirectory, includingPropertiesForKeys: nil) {
            downloadedLessonIDs = Set(lessonUrls.compactMap { $0.deletingPathExtension().lastPathComponent })
        }
        
        if let testUrls = try? fileManager.contentsOfDirectory(at: testsDirectory, includingPropertiesForKeys: nil) {
            downloadedTestIDs = Set(testUrls.compactMap { $0.deletingPathExtension().lastPathComponent })
        }
    }
    
    // MARK: - Lesson Operations
        
    func downloadLesson(_ lesson: Lesson) async throws {
        // Safely unwrap the Firestore Document ID
        guard let id = lesson.id else { return }
        
        // Ensure you fetch all nested questions/blocks from Firestore BEFORE passing the lesson here
        let data = try encoder.encode(lesson)
        let fileURL = lessonsDirectory.appending(path: "\(id).json")
        
        // Write atomically off the main thread
        try await Task.detached {
            try data.write(to: fileURL, options: .atomic)
        }.value
        
        downloadedLessonIDs.insert(id)
    }
    
    func removeLesson(id: String) throws {
        let fileURL = lessonsDirectory.appending(path: "\(id).json")
        if fileManager.fileExists(atPath: fileURL.path()) {
            try fileManager.removeItem(at: fileURL)
            downloadedLessonIDs.remove(id)
        }
    }
    
    func getOfflineLesson(id: String) throws -> Lesson {
        let fileURL = lessonsDirectory.appending(path: "\(id).json")
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Lesson.self, from: data)
    }
    
    // MARK: - Test Operations
        
    func downloadTest(_ test: Test) async throws {
        // Safely unwrap the Firestore Document ID
        guard let id = test.id else { return }
        
        // Ensure you fetch all nested questions/blocks from Firestore BEFORE passing the test here
        let data = try encoder.encode(test)
        let fileURL = testsDirectory.appending(path: "\(id).json")
        
        try await Task.detached {
            try data.write(to: fileURL, options: .atomic)
        }.value
        
        downloadedTestIDs.insert(id)
    }
    
    func removeTest(id: String) throws {
        let fileURL = testsDirectory.appending(path: "\(id).json")
        if fileManager.fileExists(atPath: fileURL.path()) {
            try fileManager.removeItem(at: fileURL)
            downloadedTestIDs.remove(id)
        }
    }
    
    func getOfflineTest(id: String) throws -> Test {
        let fileURL = testsDirectory.appending(path: "\(id).json")
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Test.self, from: data)
    }
}
