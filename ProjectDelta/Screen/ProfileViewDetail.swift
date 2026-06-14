//
//  ProfileViewDetail.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/20/24.
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProfileViewDetail: View {
    @Environment(AuthViewModel.self) var viewModel
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @State private var fullname: String = ""
    @State private var selectedRole: UserRole = .student
    @State private var profilePictureUrl: String = ""
    
    // Cross-platform native PhotosUI properties
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil

    var body: some View {
        NavigationStack {
            VStack {
                if let user = viewModel.currentUser {
                    Form {
                        Section(header: Text("Profile Picture")) {
                            HStack {
                                Spacer()
                                
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                    if let profileImageData {
                                        #if os(iOS)
                                        if let uiImage = UIImage(data: profileImageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        }
                                        #elseif os(macOS)
                                        if let nsImage = NSImage(data: profileImageData) {
                                            Image(nsImage: nsImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        }
                                        #endif
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
                                .buttonStyle(.plain)
                                .onChange(of: selectedPhotoItem) { oldValue, newValue in
                                    Task {
                                        if let item = newValue {
                                            if let data = try? await item.loadTransferable(type: Data.self) {
                                                profileImageData = data
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }

                        Section(header: Text("User Details")) {
                            TextField("Full Name", text: $fullname)
                            
                            TextField("Email", text: $email)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif

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
                                    if let profileImageData = profileImageData {
                                        await viewModel.uploadProfileImage(profileImageData, for: user)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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
