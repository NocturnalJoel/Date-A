import SwiftUI
import PhotosUI

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var model: ContentModel
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 99
    @State private var selectedPreference: User.Gender = .male
    @State private var showPhotoPermissionAlert = false
    @State private var isLoading = false
    
    private func loadCurrentUserPhotos() {
        guard let user = model.currentUser else {
            print("⚠️ No current user found")
            return
        }
        
        // Set loading state to true
        isLoading = true
        
        print("📸 Loading photos for user: \(user.id)")
        print("📸 URLs to load: \(user.pictureURLs)")
        
        Task {
            var images: [UIImage] = []
            for urlString in user.pictureURLs {
                do {
                    guard let url = URL(string: urlString) else {
                        print("⚠️ Invalid URL: \(urlString)")
                        continue
                    }
                    
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        print("⚠️ Bad response for URL: \(urlString)")
                        continue
                    }
                    
                    guard let image = UIImage(data: data) else {
                        print("⚠️ Couldn't create image from data: \(urlString)")
                        continue
                    }
                    
                    print("✅ Successfully loaded image from: \(urlString)")
                    images.append(image)
                } catch {
                    print("❌ Error loading image: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                print("📱 Setting \(images.count) images to selectedImages")
                selectedImages = images
                isLoading = false  // Set loading state to false when done
            }
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                HStack {
                                    Button(action: {
                                        dismiss()
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text("Settings")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.top, 20)
                
                    VStack(spacing: 28) {
                        // Photos Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile Photos")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                            
                         /*   if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                            } else
                            
                            */
                            
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
                        
                        // Age Preference
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Age Preference")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 8) {
                                RangeSlider(minValue: $minAge, maxValue: $maxAge, range: 18...99)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Text("\(Int(minAge))")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(maxAge))")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Gender Preference
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interested in")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                            .buttonStyle(.plain)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Ratio")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ZStack{
                                
                                Text("\(calculateRatio())%")
                                            .font(.system(size: 50, weight: .bold))
                                
                            }
                            
                        }
                        
                    }
                
                // Save Button
                Button {
                    Task {
                            do {
                                isLoading = true  // Use your existing loading state
                                try await model.updateUserSettings(
                                    images: selectedImages,
                                    minAge: minAge,
                                    maxAge: maxAge,
                                    genderPreference: selectedPreference
                                )
                                isLoading = false
                                // Optional: Show success message using an alert state
                            } catch {
                                isLoading = false
                                // Handle error - you might want to add an @State for error alerts
                                print("❌ Error updating settings: \(error.localizedDescription)")
                            }
                        }
                } label: {
                    
                    if isLoading {
                        
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        
                        } else {
                            
                            Text("Save Modifications")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .cornerRadius(16)
                        }
                    
                }
                .padding(.top, 8)
                .buttonStyle(.plain)
                
                // Log Out Button
                Button {
                    Task {
                            do {
                                try await model.signOut()
                            } catch {
                                print("❌ Error logging out: \(error.localizedDescription)")
                            }
                        }
                } label: {
                    Text("Log Out")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.red)
                        .cornerRadius(16)
                }
                .padding(.top, 8)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadCurrentUserPhotos()
            
            if let user = model.currentUser {
                selectedPreference = user.genderPreference
                // minAge = Double(user.minAgePreference)
                // maxAge = Double(user.maxAgePreference)
            }
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
    }
    
    private func calculateRatio() -> Int {
        guard let user = model.currentUser else { return 0 }
        
        let total = user.timesLiked + user.timesDisliked
        guard total > 0 else { return 0 }
        
        return Int((Double(user.timesLiked) / Double(total)) * 100)
    }
}

