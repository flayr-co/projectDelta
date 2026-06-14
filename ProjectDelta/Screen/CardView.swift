//
//  CardView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct CardView: View {
    // MARK: - PROPERTIES
    @Environment(AuthViewModel.self) var viewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(QuizViewModel.self) var quizViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                macOSCardLayout
                #else
                iOSCardLayout
                #endif
            }
            .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSCardLayout: some View {
        VStack {
            // Header
            if let user = viewModel.currentUser {
                HStack {
                    Text("Hello, \(user.fullname)!")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)
            }
            
            Spacer()
            
            // Centered Glassmorphic Card
            VStack(spacing: 24) {
                Text("Quick Math Quiz")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                NavigationLink {
                    SubjectGridView(navigationSource: .cardView)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "cross.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(colorScheme == .dark ? Color.pink : Color.cyan)
                        
                        Text("Start Practice")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(40)
                    .frame(width: 280, height: 280)
                    .background(Color.platformSecondarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformSystemGroupedBackground)
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSCardLayout: some View {
        VStack {
            // MARK: - HEADER
            VStack {
                if let user = viewModel.currentUser {
                    Text("Hello, \(user.fullname)!")
                        .greetingStyle()
                }
            }
            .padding(.leading, 15)
            .padding(.top, 20)
            
            Spacer()
            
            // MARK: - MAIN CONTENT
            VStack(alignment: .leading) {
                Text("Quick Math Quiz")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .padding(.bottom, 10)
                
                NavigationLink {
                    SubjectGridView(navigationSource: .cardView)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Image(systemName: "cross.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(colorScheme == .dark ? Color.pink : Color.cyan)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                }
                .buttonStyle(.plain) // Add plain style to prevent macOS highlighting oddities on pure images
                .padding(.top, 20)
            }
                
            // MARK: - FOOTER
            Spacer()
        }
    }
    #endif
}

#Preview {
    CardView()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
