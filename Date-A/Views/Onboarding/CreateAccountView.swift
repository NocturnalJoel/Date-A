//
//  CreateAccountView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-12-01.
//

import SwiftUI
import PhotosUI
import Firebase
import FirebaseStorage
import FirebaseAuth
import FirebaseAnalytics

struct BlackMenuPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accentColor(.black)
            .onAppear {
                UIView.appearance(whenContainedInInstancesOf: [UIPickerView.self]).tintColor = .black
            }
    }
}

struct CreateAccountView: View {
    @EnvironmentObject var model: ContentModel
    @Environment(\.dismiss) var dismiss
    @State private var showPhotoPermissionAlert = false
    @State private var progressValue: CGFloat = 0
    @State private var showProgress = false
    @State private var selectedReferralSource: ReferralSource = .friend
    
    // Create Account states
    @State private var firstName = ""
    @State private var age = ""
    @State private var selectedGender: User.Gender = .male
    @State private var selectedPreference: User.Gender = .male
    @State private var createEmail = ""
    @State private var createPassword = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    enum ReferralSource: String, CaseIterable {
        case friend = "From a friend"
        case news = "From the news media"
        case social = "From social media"
        case ad = "From an ad"
        case event = "From an event"
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            
            Text("Create Profile")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 20)
    }
    
    private var createAccountButton: some View {
        VStack(spacing: 16) {
            Button {
                handleCreateAccount()
            } label: {
                Text("Create Account")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .disabled(model.isLoading)
            .buttonStyle(.plain)
            
            if showProgress {
                progressView
            }
        }
        .padding(.top, 8)
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geometry.size.width * progressValue, height: 2)
                    .animation(.linear(duration: 2), value: progressValue)
            }
            .frame(height: 2)
            
            Text("Creating your account...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Main View
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                headerView
                
                VStack(spacing: 28) {
                    // Basic Information
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("", text: $firstName)
                                .font(.system(size: 17))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Age")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("", text: $age)
                                .font(.system(size: 17))
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("I am")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            Picker("", selection: $selectedGender) {
                                ForEach(User.Gender.allCases, id: \.self) { gender in
                                    Text(gender.rawValue).tag(gender)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interested in")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            Picker("", selection: $selectedPreference) {
                                ForEach(User.Gender.allCases, id: \.self) { gender in
                                    Text(gender.rawValue).tag(gender)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Account Details
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("", text: $createEmail)
                                .font(.system(size: 17))
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            SecureField("", text: $createPassword)
                                .font(.system(size: 17))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                                Text("How did you hear about us?")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                                Picker("Referral Source", selection: $selectedReferralSource) {
                                    ForEach(ReferralSource.allCases, id: \.self) { source in
                                        Text(source.rawValue)
                                            .tag(source)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.system(size: 17))
                                .modifier(BlackMenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                    }
                    
                    // Profile Photos Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile Photos")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        if model.permissionGranted && !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(selectedImages.indices, id: \.self) { index in
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 160)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                            }
                            .frame(height: 160)
                        }
                        
                        if model.permissionGranted {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: 6,
                                matching: .images
                            ) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text(selectedImages.isEmpty ? "Add Photos" : "Edit Photos")
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.gray)
                                .cornerRadius(12)
                            }
                        } else {
                            Button {
                                Task {
                                    let granted = await model.requestPermission()
                                    if !granted {
                                        showPhotoPermissionAlert = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("Add Photos")
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.gray)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                
                
                createAccountButton
                
                Text("By creating an account, you agree to the possibility of being contacted via email.")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onChange(of: selectedItems) { items in
            Task {
                selectedImages = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
                    }
                }
            }
        }
        .onChange(of: model.isLoading) { isLoading in
            if !isLoading {
                showProgress = false
                progressValue = 0
            }
        }
        .alert("Photo Access Required", isPresented: $showPhotoPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text("Please enable photo access in Settings to select photos for your profile.")
        }
        .alert("Error", isPresented: .constant(!model.errorMessage.isEmpty)) {
            Button("OK") {
                model.errorMessage = ""
            }
        } message: {
            Text(model.errorMessage)
        }
    }
    
    // MARK: - Helper Functions
    private func handleCreateAccount() {
        guard let ageInt = Int(age), ageInt >= 18 else {
            model.errorMessage = "Invalid age. Must be 18 or older."
            return
        }
        
        guard !selectedImages.isEmpty else {
            model.errorMessage = "Please select at least one photo"
            return
        }
        
        showProgress = true
        withAnimation(.linear(duration: 2)) {
            progressValue = 1.0
        }
        
        Analytics.logEvent("account_creation", parameters: [
                    "referral_source": selectedReferralSource.rawValue
                ])
        
        Task {
            do {
                try await model.createAccount(
                    firstName: firstName,
                    age: ageInt,
                    gender: selectedGender,
                    genderPreference: selectedPreference,
                    email: createEmail,
                    password: createPassword,
                    images: selectedImages
                )
            } catch {
                showProgress = false
                progressValue = 0
            }
        }
    }
}
