import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var model: ContentModel
    @State private var isSignInSheetPresented = false
    @State private var showPhotoPermissionAlert = false
    
    // Create Account states
    @State private var firstName = ""
    @State private var age = ""
    @State private var selectedGender: User.Gender = .male
    @State private var selectedPreference: User.Gender = .male
    @State private var createEmail = ""
    @State private var createPassword = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    
    // Sign In states
    @State private var signInEmail = ""
    @State private var signInPassword = ""
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                Text("Create Profile")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                
                VStack(spacing: 28) {
                    // Photos Section First
                    
                    
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
                    }
                    
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
                                .background(Color.black)
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
                                .background(Color.black)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Create Account Button
                Button {
                    guard let ageInt = Int(age), ageInt >= 18 else {
                        model.errorMessage = "Invalid age. Must be 18 or older."
                        return
                    }
                    
                    guard !selectedImages.isEmpty else {
                        model.errorMessage = "Please select at least one photo"
                        return
                    }
                    
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
                            // Error is handled in ContentModel
                        }
                    }
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
                .padding(.top, 8)
                
                // Sign In Option
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(.gray)
                    Button("Sign In") {
                        isSignInSheetPresented = true
                    }
                    .foregroundColor(.black)
                    .fontWeight(.medium)
                }
                .font(.system(size: 15))
                .padding(.top, 8)
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
        .sheet(isPresented: $isSignInSheetPresented) {
            NavigationView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("", text: $signInEmail)
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
                            SecureField("", text: $signInPassword)
                                .font(.system(size: 17))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Button {
                        Task {
                            do {
                                try await model.signIn(
                                    email: signInEmail,
                                    password: signInPassword
                                )
                                isSignInSheetPresented = false
                            } catch {
                                // Error is handled in ContentModel
                            }
                        }
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .cornerRadius(16)
                    }
                    .disabled(model.isLoading)
                }
                .padding(24)
                .navigationTitle("Welcome Back")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
