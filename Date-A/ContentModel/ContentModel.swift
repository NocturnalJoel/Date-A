import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Photos
import SwiftUI 

class ContentModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var permissionGranted = false
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    func signIn(email: String, password: String) async throws {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let docRef = db.collection("users").document(authResult.user.uid)
            let document = try await docRef.getDocument()
            
            guard let data = document.data() else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
            }
            
            let decodedUser = try Firestore.Decoder().decode(User.self, from: data)
            
            DispatchQueue.main.async {
                self.currentUser = decodedUser
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func createAccount(firstName: String, age: Int, gender: User.Gender,
                      genderPreference: User.Gender, email: String,
                      password: String, images: [UIImage]) async throws {
        print("📝 Starting account creation process")
        print("📸 Number of images to upload: \(images.count)")
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }
        defer {
            print("🔄 Account creation process ended")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        do {
            // 1. Create Authentication account
            print("🔑 Creating authentication account...")
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let userId = authResult.user.uid
            print("✅ Auth account created successfully with ID: \(userId)")
            
            // 2. Upload images to Storage
            print("📤 Starting image uploads...")
            var pictureURLs: [String] = []
            
            for (index, image) in images.enumerated() {
                print("🖼️ Processing image \(index + 1) of \(images.count)")
                
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    print("❌ Failed to process image \(index + 1)")
                    try? await Auth.auth().currentUser?.delete()
                    throw NSError(domain: "", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to process image \(index + 1)"])
                }
                
                let filename = "picture\(index)_\(Date().timeIntervalSince1970).jpg"
                let storageRef = storage.reference()
                    .child("users")
                    .child(userId)
                    .child(filename)
                
                print("📁 Creating storage reference: \(storageRef.fullPath)")
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                print("⏳ Starting upload...")
                _ = try await storageRef.putData(imageData, metadata: metadata)
                print("✅ Data uploaded successfully")
                
                // Add verification loop for download URL
                var urlAttempts = 0
                var downloadURL: URL?
                
                while urlAttempts < 5 && downloadURL == nil {
                    do {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds wait
                        downloadURL = try await storageRef.downloadURL()
                        print("✅ Got download URL after \(urlAttempts + 1) attempts")
                        break
                    } catch {
                        urlAttempts += 1
                        print("⏳ Waiting for URL availability... Attempt \(urlAttempts)")
                        if urlAttempts >= 5 {
                            print("❌ Failed to get download URL after 5 attempts")
                            try? await Auth.auth().currentUser?.delete()
                            throw NSError(domain: "", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to complete image upload. Please try again."])
                        }
                    }
                }
                
                if let url = downloadURL {
                    pictureURLs.append(url.absoluteString)
                    print("✅ Successfully uploaded image \(index + 1)")
                }
            }
            
            print("✅ All images uploaded successfully")
            
            // 3. Create User object
            print("👤 Creating user object...")
            let newUser = User(
                id: userId,
                firstName: firstName,
                age: age,
                gender: gender,
                genderPreference: genderPreference,
                email: email,
                pictureURLs: pictureURLs,
                timesShown: 0,
                timesLiked: 0,
                minAgePreference: 18,
                maxAgePreference: 99
            )
            
            // 4. Create Firestore document
            print("📄 Creating Firestore document...")
            try await db.collection("users").document(userId).setData(from: newUser)
            print("✅ Firestore document created successfully")
            
            DispatchQueue.main.async {
                self.currentUser = newUser
            }
            
            print("🎉 Account creation completed successfully!")
        } catch {
            print("❌ Account creation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func requestPermission() async -> Bool {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            switch status {
            case .authorized, .limited:
                DispatchQueue.main.async {
                    self.permissionGranted = true
                }
                return true
                
            case .notDetermined:
                let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                }
                return granted
                
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.permissionGranted = false
                }
                return false
                
            @unknown default:
                return false
            }
        }
}
