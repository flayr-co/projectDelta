//
//  SubjectGridView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/27/23.
//

import SwiftUI
import Firebase

enum NavigationSource {
    case homeView
    case cardView
    case testView
}

struct SubjectGridView: View {
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var navigationSource: NavigationSource
    
    // Subtopics usually fetched from Firestore or Hardcoded based on curriculum
    let mathSubtopics: [String: [String]] = [
        "Algebra": ["Linear Equations", "Systems of Equations", "Inequalities", "Functions"],
        "Advanced Math": ["Polynomials", "Rational Expressions", "Exponents", "Radicals"],
        "Problem Solving & Data Analysis": ["Ratios", "Percentages", "Probability", "Statistics"],
        "Geometry & Trigonometry": ["Area & Volume", "Right Triangles", "Circle Theorems", "Trig Identities"]
    ]
    
    @State private var selectedMainSubject: String? = nil
    @State private var showingSubtopics: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left").font(.system(size: 16, weight: .bold)).foregroundColor(.red).padding(8)
                        }.buttonStyle(.plain)
                        Spacer()
                    }.padding(.horizontal).padding(.top, 8)
                    
                    Text(showingSubtopics ? "Pick a Topic" : "Choose a Subject")
                        .font(.title2).fontWeight(.bold).padding(.vertical, 20)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if !showingSubtopics {
                                ForEach(quizViewModel.subjects, id: \.self) { subject in
                                    Button {
                                        selectedMainSubject = subject
                                        withAnimation { showingSubtopics = true }
                                    } label: {
                                        SubjectRow(title: subject)
                                    }
                                }
                            } else {
                                ForEach(mathSubtopics[selectedMainSubject ?? ""] ?? [], id: \.self) { subtopic in
                                    NavigationLink {
                                        destinationView(subject: selectedMainSubject ?? "", subtopic: subtopic)
                                    } label: {
                                        SubjectRow(title: subtopic, isSubtopic: true)
                                    }
                                }
                                
                                Button("Back to Subjects") {
                                    withAnimation { showingSubtopics = false }
                                }.padding().foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 10).padding(.bottom, 40)
                    }.scrollIndicators(.hidden)
                }
            }.navigationBarBackButtonHidden(true)
        }
    }
    
    @ViewBuilder
    private func destinationView(subject: String, subtopic: String) -> some View {
        switch navigationSource {
        case .homeView:
            LessonView(subjectName: subject).environment(lessonVM)
        case .testView:
            TestView(subject: subject, subtopic: subtopic).environment(quizViewModel)
        case .cardView:
            QuickTestView(subject: subject, subtopic: subtopic).environment(quizViewModel)
        }
    }
}

struct SubjectRow: View {
    var title: String
    var isSubtopic: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(RoundedRectangle(cornerRadius: 16).fill(isSubtopic ? Color.gray.opacity(0.1) : (colorScheme == .dark ? Color.cyan.opacity(0.15) : Color.blue.opacity(0.1))))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.cyan.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 24)
    }
}
