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
    
    @Published var messages: [Message] = []
    
    @Published var moonSliderLevel: Int = 2 {
        didSet {
            // Clear current profiles since they might not match new filter
            currentProfile = nil
            nextProfile = nil
            profileQueue.removeAll()
            lastFetchedUserId = nil
            
            // Fetch new profiles with new filter
            Task {
                await fetchProfiles()
            }
        }
    }
    
    func startFetchingProfiles() {
            Task { await fetchProfiles() }
        }
        
    @MainActor
    private func fetchProfiles() async {
        print("🚀 Starting fetchProfiles()")
        guard !isLoadingProfiles else {
            print("⚠️ Already loading profiles, skipping fetch")
            return
        }
        isLoadingProfiles = true
        print("✅ Set isLoadingProfiles to true")
        
        do {
            guard let currentUserId = Auth.auth().currentUser?.uid,
                  let currentUser = self.currentUser else {
                print("❌ Failed to get currentUserId or currentUser")
                print("currentUserId exists: \(Auth.auth().currentUser?.uid != nil)")
                print("currentUser exists: \(self.currentUser != nil)")
                isLoadingProfiles = false
                return
            }
            
            print("👤 Current User Info:")
            print("ID: \(currentUserId)")
            print("Gender Preference: \(currentUser.genderPreference.rawValue)")
            print("Age Range: \(currentUser.minAgePreference) - \(currentUser.maxAgePreference)")
            
            // Get liked and disliked users
            print("📥 Fetching disliked users...")
            let dislikedDocs = try await db.collection("users")
                .document(currentUserId)
                .collection("dislikes")
                .getDocuments()
            
            print("📥 Fetching liked users...")
            let likedDocs = try await db.collection("users")
                .document(currentUserId)
                .collection("likes_sent")
                .getDocuments()
            
            let dislikedIds = dislikedDocs.documents.map { $0.documentID }
            let likedIds = likedDocs.documents.map { $0.documentID }
            
            print("📊 Filter Stats:")
            print("Number of disliked users: \(dislikedIds.count)")
            print("Number of liked users: \(likedIds.count)")
            
            // Build query with all filters
            print("🔄 Building query with filters...")
            var query = db.collection("users")
                .whereField("id", isNotEqualTo: currentUserId)
                .whereField("gender", isEqualTo: currentUser.genderPreference.rawValue)
                .whereField("genderPreference", isEqualTo: currentUser.gender.rawValue)
                .whereField("age", isGreaterThanOrEqualTo: currentUser.minAgePreference)
                .whereField("age", isLessThanOrEqualTo: currentUser.maxAgePreference)
                .limit(to: 15) // Increased limit since we'll filter more in memory
            
            if let lastUserId = self.lastFetchedUserId {
                print("📝 Using pagination, last user ID: \(lastUserId)")
                let lastDoc = try await db.collection("users").document(lastUserId).getDocument()
                query = query.start(afterDocument: lastDoc)
            } else {
                print("📝 First fetch, no pagination")
            }
            
            print("🔍 Executing query...")
            let querySnapshot = try await query.getDocuments()
            print("📦 Raw query returned \(querySnapshot.documents.count) documents")
            
            // Get the current selected range from MoonSliderView
            let selectedRange = getMoonSliderRange()
            print("🌙 Current moon slider range: \(selectedRange.min)-\(selectedRange.max)")
            
            let newProfiles = try querySnapshot.documents.compactMap { doc -> User? in
                print("\n🔄 Processing document ID: \(doc.documentID)")
                
                guard let user = try? doc.data(as: User.self) else {
                    print("❌ Failed to decode user document")
                    print("Raw document data: \(doc.data() ?? [:])")
                    return nil
                }
                
                // Calculate like ratio
                let totalInteractions = user.timesLiked + user.timesDisliked
                let likeRatio = totalInteractions > 0 ?
                    (Double(user.timesLiked) / Double(totalInteractions)) * 100 :
                    50.0 // Default to 50% if no interactions
                
                print("📊 User like ratio: \(likeRatio)%")
                
                // Check if ratio is within selected range
                guard likeRatio >= Double(selectedRange.min) && likeRatio <= Double(selectedRange.max) else {
                    print("❌ User filtered out - ratio outside selected range")
                    return nil
                }
                
                // Filter out liked and disliked users
                if dislikedIds.contains(user.id) {
                    print("❌ User was previously disliked")
                    return nil
                }
                
                if likedIds.contains(user.id) {
                    print("❌ User was previously liked")
                    return nil
                }
                
                print("✅ User passed all filters")
                return user
            }
            
            print("\n📊 Results Summary:")
            print("New profiles found: \(newProfiles.count)")
            
            self.lastFetchedUserId = newProfiles.last?.id
            print("📝 Updated lastFetchedUserId to: \(self.lastFetchedUserId ?? "nil")")
            
            self.profileQueue.append(contentsOf: newProfiles)
            print("📦 Current profile queue size: \(self.profileQueue.count)")
            
            // Set up profiles if needed - with safety checks
            if self.currentProfile == nil && !self.profileQueue.isEmpty {
                print("🔄 Setting up initial profiles")
                self.currentProfile = self.profileQueue.removeFirst()
                print("✅ Set currentProfile: \(self.currentProfile?.firstName ?? "nil")")
                
                // Only set nextProfile if we have another profile available
                if !self.profileQueue.isEmpty {
                    self.nextProfile = self.profileQueue.removeFirst()
                    print("✅ Set nextProfile: \(self.nextProfile?.firstName ?? "nil")")
                } else {
                    print("ℹ️ No next profile available")
                }
            } else {
                print("ℹ️ Profiles already set or queue empty")
                print("currentProfile exists: \(self.currentProfile != nil)")
                print("profileQueue empty: \(self.profileQueue.isEmpty)")
            }
            
            isLoadingProfiles = false
            print("✅ Fetch completed successfully\n")
            
        } catch {
            print("\n❌ Error in fetchProfiles:")
            print("Error description: \(error.localizedDescription)")
            print("Full error: \(error)")
            print("Debug info:")
            print("currentProfile exists: \(self.currentProfile != nil)")
            print("nextProfile exists: \(self.nextProfile != nil)")
            print("profileQueue size: \(self.profileQueue.count)")
            print("isLoadingProfiles: \(self.isLoadingProfiles)")
            print("lastFetchedUserId: \(self.lastFetchedUserId ?? "nil")")
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
    
    func sendMessage(to matchId: String, text: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let message = Message(senderId: currentUserId, text: text)
        
        try await db.collection("matches")
            .document(matchId)
            .collection("messages")
            .document(message.id)
            .setData([
                "senderId": message.senderId,
                "text": message.text,
                "timestamp": message.timestamp
            ])
    }

    func fetchMessages(for matchId: String) async throws {
       print("🎬 Starting to fetch messages for matchId: \(matchId)")
       
       do {
           let messages = try await db.collection("matches")
               .document(matchId)
               .collection("messages")
               .order(by: "timestamp", descending: false)
               .getDocuments()
           
           print("📄 Got \(messages.documents.count) documents from Firestore")
           
           let fetchedMessages = messages.documents.compactMap { doc -> Message? in
               print("🔍 Processing document with ID: \(doc.documentID)")
               print("📝 Raw document data: \(doc.data())")
               
               guard let senderId = doc.data()["senderId"] as? String else {
                   print("❌ Failed to get senderId from document")
                   return nil
               }
               
               guard let text = doc.data()["text"] as? String else {
                   print("❌ Failed to get text from document")
                   return nil
               }
               
               let timestamp: Date
               if let firestoreTimestamp = doc.data()["timestamp"] as? Timestamp {
                   timestamp = firestoreTimestamp.dateValue()
                   print("✅ Successfully converted Firestore timestamp to Date")
               } else {
                   print("⚠️ No timestamp found, using current date")
                   timestamp = Date()
               }
               
               print("✅ Successfully created Message object for document \(doc.documentID)")
               print("📱 Message details - senderId: \(senderId), text: \(text)")
               
               return Message(id: doc.documentID, senderId: senderId, text: text, timestamp: timestamp)
           }
           
           print("🔄 Converted \(fetchedMessages.count) documents to Message objects")
           
           await MainActor.run {
               self.messages = fetchedMessages
               print("📱 Updated UI with \(self.messages.count) messages")
           }
           
           print("✅ Fetch messages operation completed successfully")
           
       } catch {
           print("❌ Error fetching messages: \(error.localizedDescription)")
           print("❌ Full error: \(error)")
           throw error
       }
    }
    
    private func getMoonSliderRange() -> (min: Int, max: Int) {
        let min = moonSliderLevel * 20
        let max = min + 20
        return (min, max)
    }
}
