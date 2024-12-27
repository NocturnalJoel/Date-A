import SwiftUI
import PhotosUI
import MessageUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ContentModel
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var minAge: Double = 18
    @State private var maxAge: Double = 99
    @State private var selectedPreference: User.Gender = .male
    @State private var showPhotoPermissionAlert = false
    @State private var isPhotosLoading = false
    @State private var isSaving = false // Added for ratio loading state
    @State private var showDeleteAccount = false
    
    private func refreshUserData() async {
       
        do {
            try await model.refreshCurrentUser()
            if let user = model.currentUser {
                selectedPreference = user.genderPreference
                minAge = Double(user.minAgePreference)
                maxAge = Double(user.maxAgePreference)
            }
        } catch {
            print("❌ Error refreshing user data: \(error.localizedDescription)")
        }
        
    }
    
    private func loadCurrentUserPhotos() {
        guard let user = model.currentUser else {
            print("⚠️ No current user found")
            return
        }
        
        isPhotosLoading = true
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
                isPhotosLoading = false
            }
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
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
                    
                    // Ratio Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Ratio")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        
                            CircularProgressView(percentage: Double(calculateRatio()))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 16)
                        
                    }
                }
                
                // Save Button
                Button {
                    Task {
                        do {
                            isSaving = true
                            try await model.updateUserSettings(
                                images: selectedImages,
                                minAge: minAge,
                                maxAge: maxAge,
                                genderPreference: selectedPreference
                            )
                            await refreshUserData() // Refresh after saving
                            isSaving = false
                        } catch {
                            isSaving = false
                            print("❌ Error updating settings: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    if isSaving {
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
                .buttonStyle(.plain)
                
                Button {
                    showDeleteAccount = true
                } label: {
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showDeleteAccount) {
                    DeleteAccountView()
                        .environmentObject(model)
                }
                
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await refreshUserData() // First refresh the user data
                loadCurrentUserPhotos() // Then load the photos
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

struct ShareOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let urlScheme: String
}

struct MessageComposerView: UIViewControllerRepresentable {
    @Binding var hasSharedApp: Bool
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composeVC = MFMessageComposeViewController()
        composeVC.messageComposeDelegate = context.coordinator
        
        // Set the message body with your App Store link
        composeVC.body = "Check out this amazing app! https://apps.apple.com/your-app-link" // Replace with your app link
        
        return composeVC
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposerView
        
        init(_ messageComposerView: MessageComposerView) {
            self.parent = messageComposerView
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            // Handle the result
            if result == .sent {
                parent.hasSharedApp = true // Mark as shared only if message was actually sent
            }
            parent.isPresented = false // Dismiss the composer
        }
    }
}

struct CircularProgressView: View {
    let percentage: Double
    @State private var progress: Double = 0
    @State private var hasSharedApp = false
    @State private var showShareSheet = false
    @State private var initialAnimation: Double = 0
    
    var body: some View {
        ZStack {
            // Track Circle (background)
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                .frame(width: 150, height: 150)
            
            // Progress Circle
            Circle()
                            .trim(from: 0, to: hasSharedApp ? progress : initialAnimation)
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.5), value: initialAnimation)
                            .animation(.easeInOut(duration: 1), value: progress)
            
            // Percentage Text
            Text("\(Int(percentage))%")
                .font(.system(size: 50, weight: .bold))
            
            if !hasSharedApp {
                ZStack {
                    // First blur layer
                    
                  
                    
                    // Share button
                    Button {
                        showShareSheet = true
                    } label: {
                        Text("Share App to See Ratio")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                     
                }
            }
        }
        .onAppear {
            progress = percentage / 100
            hasSharedApp = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                initialAnimation = 1
                            }
                        }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(hasSharedApp: $hasSharedApp)
        }
    }
}

// ActivityViewController to handle system share sheet
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    @Binding var isPresented: Bool
    @Binding var hasSharedApp: Bool
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        print("Debug - Activity items being shared:", activityItems)
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            if completed {
                hasSharedApp = true
            }
            // Dismiss the system share sheet first
            isPresented = false
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct ShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasSharedApp: Bool
    @State private var showingMessageComposer = false
    @State private var showingAlert = false
    @State private var showingSystemShare = false
    
    let appURL = "https://apps.apple.com/your-app-link" // Replace with your app link
    let shareMessage = "Check out this amazing app!" // Customize your share message
    
    let shareOptions: [ShareOption] = [
        ShareOption(title: "Share", icon: "square.and.arrow.up", color: .blue, urlScheme: "")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // App Icon and Title
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.black)
                
                Text("Share the App")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Share our app with friends to unlock your ratio!")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                // Share options grid
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(shareOptions) { option in
                        Button {
                            handleShare(option)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 30))
                                Text(option.title)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(option.color.opacity(0.1))
                            .foregroundColor(option.color)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerView(hasSharedApp: $hasSharedApp, isPresented: $showingMessageComposer)
        }
        .sheet(isPresented: $showingSystemShare) {
            ActivityViewController(
                activityItems: [appURL],
                isPresented: $showingSystemShare,
                hasSharedApp: $hasSharedApp
            )
        }
        .alert("Cannot Send Message", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to send messages. Please check your device settings.")
        }
        .onChange(of: hasSharedApp) { newValue in
            if newValue {
                // Add a slight delay to make the transition smoother
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
    
    private func handleShare(_ option: ShareOption) {
        switch option.title {
        case "Messages":
            if MFMessageComposeViewController.canSendText() {
                showingMessageComposer = true
            } else {
                showingAlert = true
            }
        case "Share":
            showingSystemShare = true
        default:
            break
        }
    }
}
