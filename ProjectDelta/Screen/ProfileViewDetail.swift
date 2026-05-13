//
//  ProfileViewDetail.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/20/24.
//

import SwiftUI

struct ProfileViewDetail: View {
    @Environment(AuthViewModel.self) var viewModel
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @State private var fullname: String = ""
    @State private var selectedRole: UserRole = .student
    @State private var profilePictureUrl: String = ""
    @State private var showingImagePicker = false
    @State private var profileImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                if let user = viewModel.currentUser {
                    Form {
                        Section(header: Text("Profile Picture")) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    showingImagePicker = true
                                }) {
                                    if let profileImage = profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else if let url = URL(string: profilePictureUrl) {
                                        AsyncImage(url: url) { image in
                                            image.resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        }
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .sheet(isPresented: $showingImagePicker) {
                                    PhotoPicker(image: $profileImage)
                                }
                                Spacer()
                            }
                        }

                        Section(header: Text("User Details")) {
                            TextField("Full Name", text: $fullname)
                            TextField("Email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)

                            Picker("Account Mode", selection: $selectedRole) {
                                Text("Student").tag(UserRole.student)
                                Text("Teacher").tag(UserRole.teacher)
                                Text("Parent").tag(UserRole.parent)
                            }
                            .pickerStyle(.segmented)
                        }

                        Section {
                            Button(action: {
                                Task {
                                    if let profileImage = profileImage {
                                        await viewModel.uploadProfileImage(profileImage, for: user)
                                    }
                                    await viewModel.updateUserDetails(email: email, fullname: fullname, role: selectedRole)
                                    isPresented = false
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Save Changes")
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                            }
                            .disabled(!formIsValid)
                        }
                    }
                } else {
                    ProgressView("Loading user details...")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .onAppear {
                loadUserDetails()
            }
        }
    }

    private func loadUserDetails() {
        if let user = viewModel.currentUser {
            email = user.email
            fullname = user.fullname
            selectedRole = user.role
            profilePictureUrl = user.profilePictureUrl ?? ""
        }
    }

    private var formIsValid: Bool {
        return !email.isEmpty && email.contains("@") && !fullname.isEmpty
    }
}
