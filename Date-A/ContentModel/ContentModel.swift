import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Photos
import SwiftUI 

class ContentModel: ObservableObject {
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var permissionGranted = false
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    //
    @Published var currentProfile: User?
    @Published var nextProfile: User?
    @Published var isLoadingProfiles = false
        
    private var profileQueue: [User] = []
    private var lastFetchedUserId: String?
    
    @Published var matches: [User] = []
    
    
    
    func startFetchingProfiles() {
            Task { await fetchProfiles() }
        }
        
        @MainActor
        private func fetchProfiles() async {
        guard !isLoadingProfiles else { return }
        isLoadingProfiles = true
        
        do {
            var query = db.collection("users").limit(to: 5)
            
            if let currentUserId = Auth.auth().currentUser?.uid {
                query = query.whereField("id", isNotEqualTo: currentUserId)
            }
            
            if let lastUserId = lastFetchedUserId {
                let lastDoc = try await db.collection("users").document(lastUserId).getDocument()
                query = query.start(afterDocument: lastDoc)
            }
            
            let newProfiles = try await query.getDocuments().documents.compactMap {
                try? $0.data(as: User.self)
            }
            
            lastFetchedUserId = newProfiles.last?.id
            profileQueue.append(contentsOf: newProfiles)
            
            // Set up profiles if needed - with safety checks
            if currentProfile == nil && !profileQueue.isEmpty {
                currentProfile = profileQueue.removeFirst()
                // Only set nextProfile if we have another profile available
                if !profileQueue.isEmpty {
                    nextProfile = profileQueue.removeFirst()
                }
            }
            
            isLoadingProfiles = false
        } catch {
            print("Error fetching profiles: \(error)")
            isLoadingProfiles = false
        }
    }
        
        func moveToNextProfile() {
            currentProfile = nextProfile
            nextProfile = profileQueue.isEmpty ? nil : profileQueue.removeFirst()
            
            // Fetch more if queue is getting low
            if profileQueue.count < 2 {
                Task { await fetchProfiles() }
            }
        }
    
    //
    
    
    
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
                self.isLoggedIn = true
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
                timesDisliked: 0,
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
                self.isLoggedIn = true
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
    
    func checkAuthStatus() {
            // Simply check if user is logged in with Firebase
            if Auth.auth().currentUser != nil {
                isLoggedIn = true
            } else {
                isLoggedIn = false
            }
        }
    
    func signOut() async throws {
            do {
                try Auth.auth().signOut()
                await MainActor.run {
                    isLoggedIn = false
                    currentUser = nil
                }
            } catch {
                print("❌ Error signing out: \(error.localizedDescription)")
                throw error
            }
        }
    
    func updateUserSettings(images: [UIImage], minAge: Double, maxAge: Double, genderPreference: User.Gender) async throws {
            guard var updatedUser = currentUser else {
                throw NSError(domain: "ContentModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
            }
            
            let db = Firestore.firestore()
            let storage = Storage.storage()
            var pictureURLs: [String] = []
            
            // Only process images if they've changed from current user's images
            if images.count != updatedUser.pictureURLs.count {
                // Delete existing images from Storage
                for urlString in updatedUser.pictureURLs {
                    if let url = URL(string: urlString) {
                        let imagePath = storage.reference(forURL: url.absoluteString)
                        try? await imagePath.delete()
                    }
                }
                
                // Upload new images
                for (index, image) in images.enumerated() {
                    guard let imageData = image.jpegData(compressionQuality: 0.7) else { continue }
                    
                    let imagePath = "users/\(updatedUser.id)/profile_\(index).jpg"
                    let imageRef = storage.reference().child(imagePath)
                    
                    _ = try await imageRef.putDataAsync(imageData)
                    let downloadURL = try await imageRef.downloadURL()
                    pictureURLs.append(downloadURL.absoluteString)
                }
            } else {
                pictureURLs = updatedUser.pictureURLs
            }
            
            // Update user model
            updatedUser.pictureURLs = pictureURLs
            updatedUser.minAgePreference = Int(minAge)
            updatedUser.maxAgePreference = Int(maxAge)
            updatedUser.genderPreference = genderPreference
            
            // Create dictionary for Firestore update
            let userData: [String: Any] = [
                "pictureURLs": pictureURLs,
                "minAgePreference": Int(minAge),
                "maxAgePreference": Int(maxAge),
                "genderPreference": genderPreference.rawValue
            ]
            
            // Update Firestore
            try await db.collection("users").document(updatedUser.id).updateData(userData)
            
            // Update published current user
            await MainActor.run {
                self.currentUser = updatedUser
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
    
    func likeUser(_ likedUser: User) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // Create batch write
        let batch = db.batch()
        
        // Add to current user's likes_sent
        let likeSentRef = db.collection("users").document(currentUserId)
            .collection("likes_sent").document(likedUser.id)
        batch.setData([:], forDocument: likeSentRef)  // Empty document, just need the ID
        
        // Add to other user's likes_received
        let likeReceivedRef = db.collection("users").document(likedUser.id)
            .collection("likes_received").document(currentUserId)
        batch.setData([:], forDocument: likeReceivedRef)  // Empty document, just need the ID
        
        // Increment timesLiked for the liked user
        let userRef = db.collection("users").document(likedUser.id)
            batch.updateData(["timesLiked": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        // Commit the batch
        try await batch.commit()
        
        // Check for match
        let otherUserLikes = try await db.collection("users")
            .document(likedUser.id)
            .collection("likes_sent")
            .document(currentUserId)
            .getDocument()
        
        if otherUserLikes.exists {
            // It's a match! Handle match creation here
            try await createMatch(currentUserId: currentUserId, matchedUserId: likedUser.id)
            print("It's a match!")
            // We can implement match creation later
        }
        
        // Move to next profile
        await MainActor.run {
            moveToNextProfile()
        }
    }
    
    func dislikeUser(_ dislikedUser: User) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // Create batch write
        let batch = db.batch()
        
        // Add to current user's dislikes subcollection
        let dislikeRef = db.collection("users").document(currentUserId)
            .collection("dislikes").document(dislikedUser.id)
        batch.setData([:], forDocument: dislikeRef)
        
        // Increment timesDisliked for the disliked user
        let userRef = db.collection("users").document(dislikedUser.id)
        batch.updateData(["timesDisliked": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        // Check if the disliked user had previously liked the current user
        let previousLikeRef = db.collection("users").document(currentUserId)
            .collection("likes_received").document(dislikedUser.id)
        
        let previousLikeDoc = try await previousLikeRef.getDocument()
        
        if previousLikeDoc.exists {
            // Remove from current user's likes_received
            batch.deleteDocument(previousLikeRef)
        }
        
        // Commit the batch
        try await batch.commit()
        
        // Move to next profile
        await MainActor.run {
            moveToNextProfile()
        }
    }
    
    func createMatch(currentUserId: String, matchedUserId: String) async throws {
        let batch = db.batch()
        
        // Generate a unique match ID
        let matchId = [currentUserId, matchedUserId].sorted().joined(separator: "_")
        
        // Create match document in matches collection
        let matchData: [String: Any] = [
            "users": [currentUserId, matchedUserId]
        ]
        let matchRef = db.collection("matches").document(matchId)
        batch.setData(matchData, forDocument: matchRef)
        
        // Add match reference to both users' matches collection
        let currentUserMatchRef = db.collection("users").document(currentUserId)
            .collection("matches").document(matchId)
        let matchedUserMatchRef = db.collection("users").document(matchedUserId)
            .collection("matches").document(matchId)
        
        // Empty documents - just need the reference
        batch.setData([:], forDocument: currentUserMatchRef)
        batch.setData([:], forDocument: matchedUserMatchRef)
        
        try await batch.commit()
    }
    
    func fetchMatches() async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let matchDocs = try await db.collection("users")
            .document(currentUserId)
            .collection("matches")
            .getDocuments()
        
        var fetchedUsers: [User] = []
        
        for matchDoc in matchDocs.documents {
            // Get the full match document to get both user IDs
            let match = try await db.collection("matches")
                .document(matchDoc.documentID)
                .getDocument()
            
            if let matchData = match.data(),
               let userIds = matchData["users"] as? [String] {
                // Get the ID of the other user
                let matchedUserId = userIds.first { $0 != currentUserId } ?? ""
                
                // Get the matched user's data
                let userDoc = try await db.collection("users")
                    .document(matchedUserId)
                    .getDocument()
                
                if let matchedUser = try? userDoc.data(as: User.self) {
                    fetchedUsers.append(matchedUser)
                }
            }
        }
        
        await MainActor.run {
            self.matches = fetchedUsers
        }
    }
}
