//
//  ProfileView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/20/23.
//

// ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            if let user = viewModel.currentUser {
                List {
                    Section {
                        HStack {
                            Text(user.initials)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                                .frame(width: 72, height: 72)
                                .background(Color(.systemGray))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(user.fullname)
                                    .font(.subheadline)
                                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                    .fontWeight(.semibold)
                                    .padding(.top, 4)
                                
                                Text(user.email)
                                    .font(.footnote)
                                    .foregroundColor(colorScheme == .dark ? Color.white : Color.gray)
                            }
                        }
                    }
                    
                    Section("General") {
                        HStack {
                            SettingsRowView(imageName: "gear",
                                            title: "Version",
                                            tintColor: colorScheme == .dark ? Color.white : Color(.systemGray))
                            
                            Spacer()
                            
                            Text("1.0.0")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        }
                    }
                    
                    Section("Account") {
                        Button {
                            viewModel.signOut()
                        } label: {
                            SettingsRowView(imageName: "arrow.left.circle.fill",
                                            title: "Sign Out",
                                            tintColor: .red)
                        }
                        
                        NavigationLink {
                            UserStatsView()
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            SettingsRowView(imageName: "chart.bar.xaxis", title: "View your progress", tintColor: .cyan)
                        }
                        .navigationBarBackButtonHidden(true)
                    }
                }
            }
        } //: NAVIGATIONSTACK
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }
}

#Preview {
    let authViewModel = AuthViewModel()
    authViewModel.currentUser = User.MOCK_USERS.first
    
    return ProfileView()
        .environmentObject(authViewModel)
//        .preferredColorScheme(.dark)
}
