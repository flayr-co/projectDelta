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
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Text("Choose a Subject")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.vertical, 20)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(quizViewModel.subjects, id: \.self) { subject in
                                NavigationLink {
                                    switch navigationSource {
                                    case .homeView:
                                        LessonView(subjectName: subject)
                                            .environment(lessonVM)
                                    case .testView:
                                        TestView(subject: subject)
                                            .environment(quizViewModel)
                                    case .cardView:
                                        QuickTestView(subject: subject)
                                            .environment(quizViewModel)
                                    }
                                } label: {
                                    Text(subject)
                                        .font(.headline)
                                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 70)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(colorScheme == .dark ? Color.cyan.opacity(0.15) : Color.blue.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(colorScheme == .dark ? Color.cyan.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 1)
                                        )
                                        .contentShape(Rectangle())
                                        .padding(.horizontal, 24)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    SubjectGridView(navigationSource: .homeView)
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
        .environment(LessonViewModel())
}
