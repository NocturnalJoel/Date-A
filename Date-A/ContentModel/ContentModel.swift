import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Photos
import SwiftUI

class ContentModel: NSObject, ObservableObject {
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var permissionGranted = false
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    @Published var currentUserImages: [UIImage] = []
    
    
    @Published var preloadedImages: [String: UIImage] = [:]
    
    
    //
    @Published var currentProfile: User?
    @Published var nextProfile: User?
    @Published var isLoadingProfiles = false
        
    private var profileQueue: [User] = []
    var lastFetchedUserId: String?
    
    
    @Published private var preloadedStacks: [Int: [User]] = [:]
    
    
    
    @Published var unmatchedProfiles: [(id: String, name: String, imageUrl: String)] = []
    
    
    
    @Published var matches: [User] = []
    
    @Published var messages: [Message] = []
    
    @Published var isTransitioningProfiles = false
    
    @Published var nextProfileReady = false
    
    @Published var profileStack: [User] = []  // Will hold 5 preloaded profiles
    
    private let stackSize = 10
    
    @Published var currentProfileIndex: Int = 0
    
    
    
    
    @Published var fcmToken: String?
        
        override init() {
            super.init()
            
            // Listen for FCM token updates
            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(updateFCMToken),
                                                 name: Notification.Name("FCMToken"),
                                                 object: nil)
        }

    @Published var hasMoreProfilesToFetch = true
    
    @Published var hasReachedEnd = false
    
    @Published var moonSliderLevel: Int = 2 {
        didSet {
            print("🌙 Moon level changed to: \(moonSliderLevel)")
            Task { @MainActor in
                print("📦 Current preloaded stacks: \(preloadedStacks.keys.map { "Level \($0): \(preloadedStacks[$0]?.count ?? 0) profiles" }.joined(separator: ", "))")
                
                // Reset states for new moon level
                self.lastFetchedUserId = nil
                self.hasReachedEnd = false
                self.isLoadingProfiles = false
                
                // Clear current stack
                profileStack.removeAll()
                
                // If we have preloaded profiles and their images for this level, use them
                if let preloadedProfiles = preloadedStacks[moonSliderLevel] {
                    print("✨ Found \(preloadedProfiles.count) preloaded profiles for level \(moonSliderLevel)")
                    
                    // Verify all images are preloaded
                    let allImagesPreloaded = preloadedProfiles.allSatisfy { user in
                        user.pictureURLs.allSatisfy { url in
                            preloadedImages[url] != nil
                        }
                    }
                    
                    if allImagesPreloaded {
                        print("🖼️ All images are preloaded for level \(moonSliderLevel)")
                        profileStack = preloadedProfiles
                        preloadedStacks[moonSliderLevel] = nil
                    } else {
                        print("⚠️ Some images not preloaded, starting fresh fetch")
                        await fetchProfiles()
                    }
                } else {
                    print("🚀 Starting fresh fetch for level \(moonSliderLevel)")
                    await fetchProfiles()
                }
                
                // Start preloading other levels
                await preloadAllOtherLevels(currentLevel: moonSliderLevel)
            }
        }
    }
    
    private var imagePreloadQueue: OperationQueue = {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 3 // Limit concurrent downloads
            return queue
        }()
        
        // Enhance existing image cache
        var imageCache: NSCache<NSString, UIImage> = {
            let cache = NSCache<NSString, UIImage>()
            cache.countLimit = 200 // Increased to handle preloaded images
            return cache
        }()

    
    @objc private func updateFCMToken(_ notification: Notification) {
        print("📱 updateFCMToken called in ContentModel")
        if let token = notification.userInfo?["token"] as? String {
            print("🔄 Received new FCM token in ContentModel: \(token)")
            self.fcmToken = token
            // Don't try to update Firestore here - wait for explicit login
            print("💾 Token stored locally, waiting for user login")
        }
    }
    func preloadCurrentUserImages() async {
        guard let user = currentUser else {
            print("⚠️ No current user found")
            return
        }
        
        print("📸 Preloading images for user: \(user.id)")
        print("📸 URLs to load: \(user.pictureURLs)")
        
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
            print("📱 Setting \(images.count) current user images")
            self.currentUserImages = images
        }
    }
    
    func clearPreloadedImages() {
        preloadedImages.removeAll()
    }

    func areImagesPreloaded(for user: User) -> Bool {
        user.pictureURLs.allSatisfy { url in
            preloadedImages[url] != nil
        }
    }

    func getPreloadedImage(for url: String) -> UIImage? {
        preloadedImages[url]
    }

    private func updateUserFCMToken(userId: String, token: String) async throws {
        print("📝 Starting Firestore token update for user: \(userId)")
        print("🔑 Token to save: \(token)")
        
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": token
            ])
            print("✅ Token successfully saved to Firestore")
        } catch {
            print("❌ Error saving token to Firestore: \(error)")
            throw error
        }
    }
    
     
        
        // Add a function to pre-fetch images
        private func preFetchMatchImages() async {
            for match in matches {
                guard let firstImageURL = match.pictureURLs.first,
                      let url = URL(string: firstImageURL) else { continue }
                
                // Skip if already cached
                if imageCache.object(forKey: firstImageURL as NSString) != nil {
                    continue
                }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        imageCache.setObject(image, forKey: firstImageURL as NSString)
                    }
                } catch {
                    print("Error pre-fetching image: \(error)")
                }
            }
        }
    
    func startFetchingProfiles() {
            Task { @MainActor in
                self.lastFetchedUserId = nil
                self.hasReachedEnd = false
                await fetchProfiles()
            }
        }
    
    func fetchMoreProfilesIfNeeded() {
            Task {
                if profileStack.count < 3 && !hasReachedEnd && !isLoadingProfiles {
                    await fetchProfiles()
                }
            }
        }
        
    @MainActor
    private func fetchProfiles() async {
        guard !isLoadingProfiles, !hasReachedEnd else {
            print("⚠️ Skipping fetch - isLoadingProfiles: \(isLoadingProfiles), hasReachedEnd: \(hasReachedEnd)")
            return
        }
        
        isLoadingProfiles = true
        print("🎯 Starting profile fetch for moon level \(moonSliderLevel)")
        
        do {
            guard let currentUserId = Auth.auth().currentUser?.uid,
                  let currentUser = self.currentUser else {
                print("❌ No current user found")
                isLoadingProfiles = false
                return
            }
            
            // Get filters
            let dislikedDocs = try await db.collection("users")
                .document(currentUserId)
                .collection("dislikes")
                .getDocuments()
            
            let likedDocs = try await db.collection("users")
                .document(currentUserId)
                .collection("likes_sent")
                .getDocuments()
            
            let dislikedIds = dislikedDocs.documents.map { $0.documentID }
            let likedIds = likedDocs.documents.map { $0.documentID }
            
            print("🎭 Found \(dislikedIds.count) dislikes and \(likedIds.count) likes")
            
            // Build query
            var query = db.collection("users")
                .whereField("id", isNotEqualTo: currentUserId)
                .whereField("gender", isEqualTo: currentUser.genderPreference.rawValue)
                .whereField("genderPreference", isEqualTo: currentUser.gender.rawValue)
                .whereField("age", isGreaterThanOrEqualTo: currentUser.minAgePreference)
                .whereField("age", isLessThanOrEqualTo: currentUser.maxAgePreference)
                .limit(to: stackSize)
            
            if let lastUserId = self.lastFetchedUserId {
                print("📄 Paginating after user: \(lastUserId)")
                let lastDoc = try await db.collection("users").document(lastUserId).getDocument()
                if lastDoc.exists {
                    query = query.start(afterDocument: lastDoc)
                } else {
                    // If the last document doesn't exist anymore, we've reached the end
                    hasReachedEnd = true
                    isLoadingProfiles = false
                    print("🏁 Last document no longer exists, reached end")
                    return
                }
            }
            
            let querySnapshot = try await query.getDocuments()
            print("📦 Received \(querySnapshot.documents.count) documents from Firestore")
            
            if querySnapshot.documents.isEmpty {
                hasReachedEnd = true
                isLoadingProfiles = false
                print("🏁 No more documents, reached end")
                return
            }
            
            let selectedRange = getMoonSliderRange()
            print("🌙 Filtering for ratio range: \(selectedRange.min)-\(selectedRange.max)")
            
            var uniqueProfiles = Set<User>()
            for doc in querySnapshot.documents {
                guard let user = try? doc.data(as: User.self) else { continue }
                
                if dislikedIds.contains(user.id) ||
                   likedIds.contains(user.id) ||
                   profileStack.contains(where: { $0.id == user.id }) {
                    print("👥 Skipping user \(user.id) - already interacted or in stack")
                    continue
                }
                
                let totalInteractions = user.timesLiked + user.timesDisliked
                let likeRatio = totalInteractions > 0 ?
                    (Double(user.timesLiked) / Double(totalInteractions)) * 100 :
                    50.0
                
                if likeRatio >= Double(selectedRange.min) && likeRatio <= Double(selectedRange.max) {
                    uniqueProfiles.insert(user)
                } else {
                    print("📊 User \(user.id) ratio (\(likeRatio)) outside range \(selectedRange.min)-\(selectedRange.max)")
                }
            }
            
            // Update pagination with the actual last document
            self.lastFetchedUserId = querySnapshot.documents.last?.documentID
            print("📝 Updated last fetched ID to: \(self.lastFetchedUserId ?? "nil")")
            
            let newProfiles = Array(uniqueProfiles)
            print("✨ Found \(newProfiles.count) new matching profiles")
            
            // Preload images
            await preloadImagesForUsers(newProfiles)
            print("🖼️ Preloaded images for new profiles")
            
            // Update UI
            if profileStack.isEmpty {
                profileStack = newProfiles
                print("📚 Set new profiles as stack")
            } else {
                profileStack.append(contentsOf: newProfiles)
                print("📚 Appended \(newProfiles.count) profiles to stack")
            }
            
            isLoadingProfiles = false
            
            // If we found no new profiles and still have more to fetch, try next batch
            if newProfiles.isEmpty && !querySnapshot.documents.isEmpty {
                print("🔄 No new profiles in this batch, fetching next batch")
                await fetchProfiles()
            } else if newProfiles.isEmpty && querySnapshot.documents.isEmpty {
                print("🏁 No more profiles to fetch")
                hasReachedEnd = true
            }
            
        } catch {
            print("❌ Error fetching profiles: \(error)")
            isLoadingProfiles = false
        }
    }

    
    private func fetchProfilesForLevel(_ level: Int) async throws -> [User] {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let currentUser = self.currentUser else {
            return []
        }
        
        let dislikedDocs = try await db.collection("users")
            .document(currentUserId)
            .collection("dislikes")
            .getDocuments()
        
        let likedDocs = try await db.collection("users")
            .document(currentUserId)
            .collection("likes_sent")
            .getDocuments()
        
        let dislikedIds = dislikedDocs.documents.map { $0.documentID }
        let likedIds = likedDocs.documents.map { $0.documentID }
        
        var query = db.collection("users")
            .whereField("id", isNotEqualTo: currentUserId)
            .whereField("gender", isEqualTo: currentUser.genderPreference.rawValue)
            .whereField("genderPreference", isEqualTo: currentUser.gender.rawValue)
            .whereField("age", isGreaterThanOrEqualTo: currentUser.minAgePreference)
            .whereField("age", isLessThanOrEqualTo: currentUser.maxAgePreference)
            .limit(to: stackSize)
        
        if let lastUserId = self.lastFetchedUserId {
            let lastDoc = try await db.collection("users").document(lastUserId).getDocument()
            query = query.start(afterDocument: lastDoc)
        }
        
        let querySnapshot = try await query.getDocuments()
        let selectedRange = getMoonSliderRangeForLevel(level)
        
        let profiles = try querySnapshot.documents.compactMap { doc -> User? in
            guard let user = try? doc.data(as: User.self) else { return nil }
            
            let totalInteractions = user.timesLiked + user.timesDisliked
            let likeRatio = totalInteractions > 0 ?
                (Double(user.timesLiked) / Double(totalInteractions)) * 100 :
                50.0
            
            guard likeRatio >= Double(selectedRange.min) && likeRatio <= Double(selectedRange.max) else {
                return nil
            }
            
            if dislikedIds.contains(user.id) || likedIds.contains(user.id) {
                return nil
            }
            
            return user
        }
        
        // Preload images for these profiles
        await preloadImagesForUsers(profiles)
        return profiles
    }
     func preloadImagesForUser(_ user: User) async {
        for imageURL in user.pictureURLs {
            // Skip if already preloaded
            if preloadedImages[imageURL] != nil {
                continue
            }
            
            guard let url = URL(string: imageURL) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        preloadedImages[imageURL] = image
                    }
                }
            } catch {
                print("Error preloading image: \(error)")
            }
        }
    }
        
        // Add function to preload images for multiple users
    private func preloadImagesForUsers(_ users: [User]) async {
        await withTaskGroup(of: Void.self) { group in
            for user in users {
                group.addTask {
                    await self.preloadImagesForUser(user)
                }
            }
        }
    }
        // Function for preloading all other moon levels
    private func preloadAllOtherLevels(currentLevel: Int) async {
        let allOtherLevels = Array(0...4).filter { $0 != currentLevel }
        
        await withTaskGroup(of: Void.self) { group in
            for level in allOtherLevels {
                if preloadedStacks[level] == nil {
                    group.addTask {
                        do {
                            print("🔄 Starting preload for level \(level)")
                            self.lastFetchedUserId = nil
                            let preloadedProfiles = try await self.fetchProfilesForLevel(level)
                            
                            if !preloadedProfiles.isEmpty {
                                // Verify all images are preloaded
                                let allImagesPreloaded = await MainActor.run {
                                    preloadedProfiles.allSatisfy { user in
                                        self.areImagesPreloaded(for: user)
                                    }
                                }
                                
                                if allImagesPreloaded {
                                    await MainActor.run {
                                        self.preloadedStacks[level] = preloadedProfiles
                                        print("✅ Successfully preloaded level \(level) with \(preloadedProfiles.count) profiles")
                                    }
                                } else {
                                    print("⚠️ Not all images were preloaded for level \(level)")
                                }
                            }
                        } catch {
                            print("❌ Error preloading profiles for level \(level): \(error)")
                        }
                    }
                }
            }
        }
    }
        
        private func getMoonSliderRangeForLevel(_ level: Int) -> (min: Int, max: Int) {
            let min = level * 20
            let max = min + 20
            return (min, max)
        }
        
        @MainActor
        func moveToNextProfile() {
            currentProfileIndex += 1
            
            // If we've reached the end of the stack, reset and fetch new profiles
            if currentProfileIndex >= profileStack.count {
                profileStack = []
                currentProfileIndex = 0
                Task {
                    await fetchProfiles()
                }
            }
        }
    
    //
    
    
    func signIn(email: String, password: String) async throws {
        print("🔐 Starting sign in process")
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Firebase Auth sign in successful")
            
            let docRef = db.collection("users").document(authResult.user.uid)
            let document = try await docRef.getDocument()
            
            guard let data = document.data() else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
            }
            
            let decodedUser = try Firestore.Decoder().decode(User.self, from: data)
            
            // Update FCM token only after successful login
            if let fcmToken = self.fcmToken {
                print("📱 Updating FCM token after login for user: \(authResult.user.uid)")
                print("🔑 Token to update: \(fcmToken)")
                try await updateUserFCMToken(userId: authResult.user.uid, token: fcmToken)
            }
            
            await MainActor.run {
                self.currentUser = decodedUser
                self.isLoggedIn = true
                print("✅ User successfully logged in and state updated")
            }
        } catch {
            print("❌ Sign in error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
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
                maxAgePreference: 99,
                fcmToken: self.fcmToken
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
        if Auth.auth().currentUser != nil {
            // Instead of immediately setting isLoggedIn to true,
            // fetch the user data first
            Task {
                do {
                    try await refreshCurrentUser()
                    await MainActor.run {
                        self.isLoggedIn = true
                    }
                } catch {
                    print("❌ Error refreshing user: \(error)")
                    await MainActor.run {
                        self.isLoggedIn = false
                    }
                }
            }
        } else {
            isLoggedIn = false
        }
    }

    
    func signOut() async throws {
        if let userId = Auth.auth().currentUser?.uid {
                    try await updateUserFCMToken(userId: userId, token: "")
                }
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
    
    // In ContentModel
    // In ContentModel
    func likeUser(_ likedUser: User) async throws {
        let likedUserId = likedUser.id
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // Create batch write
        let batch = db.batch()
        
        // Add to current user's likes_sent
        let likeSentRef = db.collection("users").document(currentUserId)
            .collection("likes_sent").document(likedUserId)
        batch.setData([:], forDocument: likeSentRef)
        
        // Add to other user's likes_received
        let likeReceivedRef = db.collection("users").document(likedUserId)
            .collection("likes_received").document(currentUserId)
        batch.setData([:], forDocument: likeReceivedRef)
        
        // Increment timesLiked for the liked user
        let userRef = db.collection("users").document(likedUserId)
        batch.updateData(["timesLiked": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        // Commit the batch
        try await batch.commit()
        
        // Check for match
        let otherUserLikes = try await db.collection("users")
            .document(likedUserId)
            .collection("likes_sent")
            .document(currentUserId)
            .getDocument()
        
        if otherUserLikes.exists {
            try await createMatch(currentUserId: currentUserId, matchedUserId: likedUserId)
        }
        
        // Update UI after successful database operation
        await MainActor.run {
            // Remove the first profile from the stack
            if !profileStack.isEmpty {
                profileStack.removeFirst()
            }
            
            // If stack is empty, fetch new profiles
            if profileStack.isEmpty {
                Task {
                    await fetchProfiles()
                }
            }
        }
    }

    func dislikeUser(_ dislikedUser: User) async throws {
        let dislikedUserId = dislikedUser.id
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // Create batch write
        let batch = db.batch()
        
        // Add to current user's dislikes
        let dislikeRef = db.collection("users").document(currentUserId)
            .collection("dislikes").document(dislikedUserId)
        batch.setData([:], forDocument: dislikeRef)
        
        // Increment timesDisliked for the disliked user
        let userRef = db.collection("users").document(dislikedUserId)
        batch.updateData(["timesDisliked": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        // Check if the disliked user had previously liked the current user
        let previousLikeRef = db.collection("users").document(currentUserId)
            .collection("likes_received").document(dislikedUserId)
        
        let previousLikeDoc = try await previousLikeRef.getDocument()
        if previousLikeDoc.exists {
            batch.deleteDocument(previousLikeRef)
        }
        
        // Commit the batch
        try await batch.commit()
        
        // Update UI after successful database operation
        await MainActor.run {
            // Remove the first profile from the stack
            if !profileStack.isEmpty {
                profileStack.removeFirst()
            }
            
            // If stack is empty, fetch new profiles
            if profileStack.isEmpty {
                Task {
                    await fetchProfiles()
                }
            }
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
        await preFetchMatchImages()
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
    
    func refreshCurrentUser() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let docRef = db.collection("users").document(userId)
        let document = try await docRef.getDocument()
        
        guard let userData = try? document.data(as: User.self) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not decode user data"])
        }
        
        await MainActor.run {
            self.currentUser = userData
        }
        await preloadCurrentUserImages()
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser,
              let currentUser = self.currentUser else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
        }
        
        // Create batch write for Firestore operations
        let batch = db.batch()
        
        // Delete user's Firestore document
        let userRef = db.collection("users").document(user.uid)
        batch.deleteDocument(userRef)
        
        // Delete matches
        let matchesRef = userRef.collection("matches")
        let matchesDocs = try await matchesRef.getDocuments()
        for doc in matchesDocs.documents {
            // Delete the match document from the matches collection
            batch.deleteDocument(db.collection("matches").document(doc.documentID))
            batch.deleteDocument(doc.reference)
        }
        
        // Delete likes_sent and likes_received
        let likesSentDocs = try await userRef.collection("likes_sent").getDocuments()
        for doc in likesSentDocs.documents {
            batch.deleteDocument(doc.reference)
        }
        
        let likesReceivedDocs = try await userRef.collection("likes_received").getDocuments()
        for doc in likesReceivedDocs.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Delete dislikes
        let dislikesDocs = try await userRef.collection("dislikes").getDocuments()
        for doc in dislikesDocs.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Commit Firestore changes
        try await batch.commit()
        
        // Delete images from Storage
        for urlString in currentUser.pictureURLs {
            if let url = URL(string: urlString),
               let storagePath = url.path.components(separatedBy: "o/").last?.removingPercentEncoding {
                let storageRef = Storage.storage().reference().child(storagePath)
                try await storageRef.delete()
            }
        }
        
        // Delete Firebase Auth account
        try await user.delete()
        
        // Clear local state
        await MainActor.run {
            self.currentUser = nil
            self.isLoggedIn = false
        }
    }
    
    // Add these functions inside your ContentModel class

    func updateMatchSocialRequest(matchId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let matchRef = db.collection("matches").document(matchId)
        
        // First, get the current state of the document
        let matchDoc = try await matchRef.getDocument()
        let data = matchDoc.data()
        
        var updates: [String: Any] = [:]
        
        // Check if there's already a social request from the other user
        if let existingSocialRequest = data?["socialRequest"] as? [String: Any],
           let otherUserId = (data?["users"] as? [String])?.first(where: { $0 != currentUserId }) {
            
            // If the other user has already requested, add both users to confirmed
            if existingSocialRequest[otherUserId] as? Bool == true {
                updates["socialRequestConfirmed"] = true
            }
        }
        
        // Add or update current user's request
        updates["socialRequest.\(currentUserId)"] = true
        
        try await matchRef.updateData(updates)
    }

    func updateMatchDateRequest(matchId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let matchRef = db.collection("matches").document(matchId)
        
        // First, get the current state of the document
        let matchDoc = try await matchRef.getDocument()
        let data = matchDoc.data()
        
        var updates: [String: Any] = [:]
        
        // Check if there's already a date request from the other user
        if let existingDateRequest = data?["dateRequest"] as? [String: Any],
           let otherUserId = (data?["users"] as? [String])?.first(where: { $0 != currentUserId }) {
            
            // If the other user has already requested, add both users to confirmed
            if existingDateRequest[otherUserId] as? Bool == true {
                updates["dateRequestConfirmed"] = true
            }
        }
        
        // Add or update current user's request
        updates["dateRequest.\(currentUserId)"] = true
        
        try await matchRef.updateData(updates)
    }
    
    func fetchMatchState(matchId: String) async throws -> (hasSocialRequest: Bool, hasDateRequest: Bool) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return (false, false)
        }
        
        let matchDoc = try await db.collection("matches").document(matchId).getDocument()
        if let data = matchDoc.data() {
            let socialRequest = data["socialRequest"] as? [String: Any]
            let dateRequest = data["dateRequest"] as? [String: Any]
            
            return (
                hasSocialRequest: (socialRequest?[currentUserId] as? Bool) == true,
                hasDateRequest: (dateRequest?[currentUserId] as? Bool) == true
            )
        }
        
        return (false, false)
    }
    
    func unmatchAndRate(matchId: String, rating: Int) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get the match document to find the other user's ID
        let matchDoc = try await db.collection("matches").document(matchId).getDocument()
        guard let data = matchDoc.data(),
              let users = data["users"] as? [String],
              let otherUserId = users.first(where: { $0 != currentUserId }) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid match data"])
        }
        
        // Get the other user's current rating data
        let otherUserDoc = try await db.collection("users").document(otherUserId).getDocument()
        let otherUserData = otherUserDoc.data() ?? [:]
        
        // Extract current rating data, defaulting to 5.0 if none exists
        let currentRating = (otherUserData["chatReview"] as? [String: Any])?["chatRating"] as? Double ?? 5.0
        let currentNumberOfRates = (otherUserData["chatReview"] as? [String: Any])?["numberOfRates"] as? Int ?? 0
        
        // Calculate new average rating
        let totalCurrentRating = currentRating * Double(currentNumberOfRates)
        let newNumberOfRates = currentNumberOfRates + 1
        let newAverageRating = (totalCurrentRating + Double(rating)) / Double(newNumberOfRates)
        
        let batch = db.batch()
        
        // Delete match document
        let matchRef = db.collection("matches").document(matchId)
        batch.deleteDocument(matchRef)
        
        // Delete match from current user's matches collection
        let currentUserMatchRef = db.collection("users").document(currentUserId)
            .collection("matches").document(matchId)
        batch.deleteDocument(currentUserMatchRef)
        
        // Delete match from other user's matches collection
        let otherUserMatchRef = db.collection("users").document(otherUserId)
            .collection("matches").document(matchId)
        batch.deleteDocument(otherUserMatchRef)
        
        // Update other user's document with unmatches array, numberOfRates, and new average rating
        let otherUserRef = db.collection("users").document(otherUserId)
        batch.updateData([
            "unmatches": FieldValue.arrayUnion([currentUserId]),
            "chatReview.numberOfRates": newNumberOfRates,
            "chatReview.chatRating": newAverageRating
        ], forDocument: otherUserRef)
        
        try await batch.commit()
    }

    func fetchUnmatchedProfiles() async throws -> [(id: String, name: String, imageUrl: String)] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user ID")
            return []
        }
        
        print("📄 Fetching user document for ID: \(currentUserId)")
        let userDoc = try await db.collection("users").document(currentUserId).getDocument()
        let unmatches = userDoc.data()?["unmatches"] as? [String] ?? []
        print("📋 Found \(unmatches.count) unmatches in user document")
        
        var profiles: [(id: String, name: String, imageUrl: String)] = []
        
        for unmatchId in unmatches {
            print("🔍 Fetching profile for unmatch ID: \(unmatchId)")
            let unmatchDoc = try await db.collection("users").document(unmatchId).getDocument()
            if let data = unmatchDoc.data(),
               let name = data["firstName"] as? String,  // Changed from "name" to "firstName" to match your User model
               let imageUrl = data["pictureURLs"] as? [String],  // Changed to match your User model
               let firstImage = imageUrl.first {
                profiles.append((id: unmatchId, name: name, imageUrl: firstImage))
                print("✅ Added profile for \(name)")
            }
        }
        
        print("📱 Returning \(profiles.count) profiles")
        return profiles
    }

    func rateUnmatchedUser(unmatchedUserId: String, rating: Int) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get the unmatcher's current rating data
        let unmatcherDoc = try await db.collection("users").document(unmatchedUserId).getDocument()
        let unmatcherData = unmatcherDoc.data() ?? [:]
        
        // Extract current rating data, defaulting to 5.0 if none exists
        let currentRating = (unmatcherData["chatReview"] as? [String: Any])?["chatRating"] as? Double ?? 5.0
        let currentNumberOfRates = (unmatcherData["chatReview"] as? [String: Any])?["numberOfRates"] as? Int ?? 0
        
        // Calculate new average rating
        let totalCurrentRating = currentRating * Double(currentNumberOfRates)
        let newNumberOfRates = currentNumberOfRates + 1
        let newAverageRating = (totalCurrentRating + Double(rating)) / Double(newNumberOfRates)
        
        let batch = db.batch()
        
        // Update unmatcher's rating
        let unmatcherRef = db.collection("users").document(unmatchedUserId)
        batch.updateData([
            "chatReview.chatRating": newAverageRating,
            "chatReview.numberOfRates": newNumberOfRates
        ], forDocument: unmatcherRef)
        
        // Remove unmatcher's ID from current user's unmatches array
        let currentUserRef = db.collection("users").document(currentUserId)
        batch.updateData([
            "unmatches": FieldValue.arrayRemove([unmatchedUserId])
        ], forDocument: currentUserRef)
        
        try await batch.commit()
    }
    
    func loadUnmatchedProfiles() async {
        let profiles = try? await fetchUnmatchedProfiles()
        await MainActor.run {
            self.unmatchedProfiles = profiles ?? []
        }
    }
    
    
}
