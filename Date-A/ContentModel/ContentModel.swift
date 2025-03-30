import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Photos
import SwiftUI
import FirebaseAnalytics

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
    @Published var isLoadingProfiles = false
    var lastFetchedUserId: String?
    @Published var unmatchedProfiles: [(id: String, name: String, imageUrl: String)] = []
    @Published var matches: [User] = []
    @Published var messages: [Message] = []
    @Published var profileStack: [User] = []  // Will hold 5 preloaded profiles
    private let stackSize = 10
    @Published var fcmToken: String?
    private let minStackSize = 5 // Threshold to trigger refresh
    private let targetStackSize = 10
    @Published private var moonLevelStacks: [Int: [User]] = [0: [], 1: [], 2: [], 3: [], 4: []]
    
    
    @Published var lastDocumentSnapshots: [Int: DocumentSnapshot] = [:] // Tracks pagination per moon level
    @Published var seenUserIDs = Set<String>()
    
    @Published var hasReachedEnd: [Int: Bool] = [:]
    
    @Published private var exhaustedLevels = Set<Int>()
    
    @Published private var allSeenProfileIDs = Set<String>()
    
    
    
    private var imagePreloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3 // Limit concurrent downloads
        return queue
    }()
    
    var imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200 // Increased to handle preloaded images
        return cache
    }()
    
    //========== INIT ==================
    
    override init() {
        
        
        moonLevelStacks = [0: [], 1: [], 2: [], 3: [], 4: []]
        super.init()
        
        // Listen for FCM token updates
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateFCMToken),
                                               name: Notification.Name("FCMToken"),
                                               object: nil)
        
        // Check for existing Firebase session
        if let firebaseUser = Auth.auth().currentUser {
            if UserDefaults.standard.bool(forKey: "isUserLoggedIn") {
                // Fetch user data from Firestore using Firebase user's ID
                fetchUserData(uid: firebaseUser.uid)
            } else {
                // Clear Firebase session if UserDefaults shows logged out
                try? Auth.auth().signOut()
            }
        }
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] (auth, firebaseUser) in
            if let firebaseUser = firebaseUser {
                if UserDefaults.standard.bool(forKey: "isUserLoggedIn") {
                    self?.fetchUserData(uid: firebaseUser.uid)
                }
            } else {
                DispatchQueue.main.async {
                    self?.currentUser = nil
                }
            }
        }
        
        
        
    }
    
    
    // ===== DEBUGGING UTILITIES =====
    private func debugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[ProfileDebug][\(timestamp)] \(message)")
    }

    private func logProfile(_ profile: User) {
        debugLog("Profile ID: \(profile.id), Name: \(profile.firstName), Age: \(profile.age), LikeRatio: \(profile.likeRatio)")
    }
    
    // ===== INTERACTION FUNCTIONS =====
    
    
    func likeUser(_ likedUser: User) async throws {
        let likedUserId = likedUser.id
        
        // 1. Verify Authentication
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
        }
        
        // 2. Calculate New Like Ratio
        let newLikes = likedUser.timesLiked + 1
        let newTotal = newLikes + likedUser.timesDisliked
        let newRatio: Double = {
            if newTotal == 0 { return 50.0 }
            return (Double(newLikes) / Double(newTotal)) * 100
        }()
        
        // 3. Firebase Batch Operation
        let batch = db.batch()
        
        // Add to likes_sent
        let likeSentRef = db.collection("users")
            .document(currentUserId)
            .collection("likes_sent")
            .document(likedUserId)
        batch.setData([:], forDocument: likeSentRef)
        
        // Add to likes_received
        let likeReceivedRef = db.collection("users")
            .document(likedUserId)
            .collection("likes_received")
            .document(currentUserId)
        batch.setData([:], forDocument: likeReceivedRef)
        
        // Update target user's stats
        let userRef = db.collection("users").document(likedUserId)
        batch.updateData([
            "timesLiked": FieldValue.increment(Int64(1)),
            "likeRatio": newRatio
        ], forDocument: userRef)
        
        // 4. Execute Batch
        try await batch.commit()
        logUserLike(targetUserAge: likedUser.age, matchOccurred: false)
        
        // 5. Check for Match
        let matchDoc = try await db.collection("users")
            .document(likedUserId)
            .collection("likes_sent")
            .document(currentUserId)
            .getDocument()
        
        if matchDoc.exists {
            logUserLike(targetUserAge: likedUser.age, matchOccurred: true)
            try await createMatch(currentUserId: currentUserId, matchedUserId: likedUserId)
        }
        
        // 6. Update Local State
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            // Remove from all stacks
            self.removeUserFromAllStacks(userId: likedUserId)
            
            // Refill if needed
            if self.profileStack.count < self.minStackSize {
                Task {
                    await self.refillProfilesIfNeeded()
                }
            }
        }
    }
    
    func dislikeUser(_ dislikedUser: User) async throws {
        let dislikedUserId = dislikedUser.id
        
        // 1. Verify Authentication
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // 2. Calculate New Ratio
        let newDislikes = dislikedUser.timesDisliked + 1
        let newTotal = dislikedUser.timesLiked + newDislikes
        let newRatio: Double = {
            if newTotal == 0 { return 50.0 }
            return (Double(dislikedUser.timesLiked) / Double(newTotal)) * 100
        }()
        
        // 3. Firebase Operations
        let batch = db.batch()
        
        // Add to dislikes
        let dislikeRef = db.collection("users")
            .document(currentUserId)
            .collection("dislikes")
            .document(dislikedUserId)
        batch.setData([:], forDocument: dislikeRef)
        
        // Update target user's stats
        let userRef = db.collection("users").document(dislikedUserId)
        batch.updateData([
            "timesDisliked": FieldValue.increment(Int64(1)),
            "likeRatio": newRatio
        ], forDocument: userRef)
        
        // Remove any existing like_received
        let previousLikeRef = db.collection("users")
            .document(currentUserId)
            .collection("likes_received")
            .document(dislikedUserId)
        let previousLikeDoc = try await previousLikeRef.getDocument()
        if previousLikeDoc.exists {
            batch.deleteDocument(previousLikeRef)
        }
        
        // 4. Execute Batch
        try await batch.commit()
        logUserDislike(targetUserAge: dislikedUser.age)
        
        // 5. Update Local State
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            // Remove from all stacks
            self.removeUserFromAllStacks(userId: dislikedUserId)
            
            // Refill if needed
            if self.profileStack.count < self.minStackSize {
                Task {
                    await self.refillProfilesIfNeeded()
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
            "users": [currentUserId, matchedUserId],
            "createdAt": FieldValue.serverTimestamp(),
            "lastActivity": FieldValue.serverTimestamp() // Add lastActivity field
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
    
    //=======STACKS REFILLS========
    
    @Published var currentMoonLevel: Int = 2 {
        didSet {
            Task { @MainActor in
                await initializeStacks()
            }
        }
    }
    
    private func fetchUserData(uid: String) {
        let docRef = db.collection("users").document(uid)
        docRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: User.self)
                    DispatchQueue.main.async {
                        self?.currentUser = user
                        self?.errorMessage = ""
                    }
                } catch {
                    print("Error decoding user: \(error)")
                    self?.errorMessage = "Error fetching user data"
                    
                }
            }
        }
    }
    
    @MainActor
    private func loadProfiles(level: Int, dislikedIds: Set<String>, likedIds: Set<String>) async {
        debugLog("⏳ Starting loadProfiles for level \(level)")
        debugLog("📊 Current state - Disliked: \(dislikedIds.count), Liked: \(likedIds.count)")
        
        // 1. Check if we've reached the end for this level
        guard (hasReachedEnd[level] ?? false) == false else {
            debugLog("🛑 Early exit - hasReachedEnd[\(level)] is true")
            return
        }
        
        // 2. Build query with all original filters
        var query = db.collection("users")
            .whereField("gender", isEqualTo: currentUser?.genderPreference.rawValue ?? "")
            .whereField("genderPreference", isEqualTo: currentUser?.gender.rawValue ?? "")
            .whereField("age", isGreaterThanOrEqualTo: currentUser?.minAgePreference ?? 18)
            .whereField("age", isLessThanOrEqualTo: currentUser?.maxAgePreference ?? 99)
            .whereField("likeRatio", isGreaterThan: Double(level * 20))
            .whereField("likeRatio", isLessThanOrEqualTo: Double((level + 1) * 20))
            .limit(to: 10)
        
        // 3. Pagination support
        if let lastDoc = lastDocumentSnapshots[level] {
            debugLog("📖 Paginating after last document ID: \(lastDoc.documentID)")
            query = query.start(afterDocument: lastDoc)
        } else {
            debugLog("🆕 Initial load for level \(level)")
        }
        
        do {
            debugLog("🔥 Executing Firestore query for level \(level)")
            let snapshot = try await query.getDocuments()
            debugLog("✅ Received \(snapshot.documents.count) documents from Firestore")
            
            var newProfiles = [User]()
            let currentStackIDs = Set(moonLevelStacks[level]?.map { $0.id } ?? [])
            var filteredCount = 0
            
            // 4. Process documents - only filter liked/disliked and current stack dupes
            for doc in snapshot.documents {
                guard let user = try? doc.data(as: User.self) else {
                    debugLog("❌ Failed to decode document \(doc.documentID)")
                    continue
                }
                
                if dislikedIds.contains(user.id) {
                    debugLog("👎 Filtered out \(user.id) - previously disliked")
                    filteredCount += 1
                    continue
                }
                
                if likedIds.contains(user.id) {
                    debugLog("👍 Filtered out \(user.id) - previously liked")
                    filteredCount += 1
                    continue
                }
                
                if currentStackIDs.contains(user.id) {
                    debugLog("🔄 Filtered out \(user.id) - already in current stack")
                    filteredCount += 1
                    continue
                }
                
                logProfile(user)
                newProfiles.append(user)
            }
            
            debugLog("🧮 Results - New: \(newProfiles.count), Filtered: \(filteredCount), Total docs: \(snapshot.documents.count)")
            
            // 5. Handle empty batches but more documents exist
            if newProfiles.isEmpty && !snapshot.documents.isEmpty {
                debugLog("🔁 No new profiles but documents exist - forcing pagination")
                lastDocumentSnapshots[level] = snapshot.documents.last
                await loadProfiles(level: level, dislikedIds: dislikedIds, likedIds: likedIds)
                return
            }
            
            // 6. Update state
            await MainActor.run {
                if moonLevelStacks[level] == nil {
                    debugLog("🏗️ Initializing empty stack for level \(level)")
                    moonLevelStacks[level] = []
                }
                
                let beforeCount = moonLevelStacks[level]?.count ?? 0
                moonLevelStacks[level]?.append(contentsOf: newProfiles)
                let afterCount = moonLevelStacks[level]?.count ?? 0
                
                debugLog("📈 Level \(level) stack growth: \(beforeCount) → \(afterCount)")
                
                lastDocumentSnapshots[level] = snapshot.documents.last
                hasReachedEnd[level] = newProfiles.isEmpty
                
                if newProfiles.isEmpty {
                    debugLog("🏁 Reached end of profiles for level \(level)")
                }
                
                updateDisplayStack()
            }
            
        } catch {
            debugLog("‼️ Error loading profiles: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load profiles"
            }
        }
    }

    func initializeStacks() async {
        guard let currentUserID = currentUser?.id else {
            debugLog("🔴 initializeStacks called without currentUser")
            return
        }
        
        debugLog("🔄 INITIALIZING STACKS for moon level \(currentMoonLevel)")
        
        // Reset all tracking state
        await MainActor.run {
            debugLog("🧹 Resetting tracking state")
            debugLog("📝 Before reset - AllSeen: \(allSeenProfileIDs.count), MoonStacks: \(moonLevelStacks.mapValues { $0.count })")
            
            // allSeenProfileIDs.removeAll()
            hasReachedEnd = [:]
            lastDocumentSnapshots = [:]
            moonLevelStacks = [0: [], 1: [], 2: [], 3: [], 4: []]
            errorMessage = ""
            
            debugLog("🆕 After reset - AllSeen: \(allSeenProfileIDs.count), MoonStacks: \(moonLevelStacks.mapValues { $0.count })")
        }
        
        // Get filtered IDs
        let (dislikedIds, likedIds) = (try? await getFilteredIds(for: currentUserID)) ?? (Set(), Set())
        debugLog("🔍 Filtered IDs - Disliked: \(dislikedIds.count), Liked: \(likedIds.count)")
        
        // Load initial profiles
        debugLog("⬇️ Starting initial profile load for level \(currentMoonLevel)")
        await loadProfiles(level: currentMoonLevel, dislikedIds: dislikedIds, likedIds: likedIds)
    }

    func refillProfilesIfNeeded() async {
        guard profileStack.count < minStackSize else {
            debugLog("🆗 No refill needed - profileStack has \(profileStack.count) items")
            return
        }
        
        guard let currentUserID = currentUser?.id else {
            debugLog("🔴 refillProfilesIfNeeded called without currentUser")
            return
        }
        
        debugLog("🔄 REFILLING PROFILES for moon level \(currentMoonLevel)")
        
        let (dislikedIds, likedIds) = (try? await getFilteredIds(for: currentUserID)) ?? (Set(), Set())
        debugLog("🔍 Refill Filtered IDs - Disliked: \(dislikedIds.count), Liked: \(likedIds.count)")
        
        await loadProfiles(level: currentMoonLevel, dislikedIds: dislikedIds, likedIds: likedIds)
    }

    
    @MainActor
    private func updateDisplayStack() {
        let beforeCount = profileStack.count
        profileStack = moonLevelStacks[currentMoonLevel] ?? []
        debugLog("🔄 Updated display stack: \(beforeCount) → \(profileStack.count) profiles")
        
        // Log current state of all levels
        debugLog("🌕 Moon Levels State:")
        for level in 0...4 {
            let count = moonLevelStacks[level]?.count ?? 0
            let reachedEnd = hasReachedEnd[level] ?? false
            debugLog("   Level \(level): \(count) profiles, reachedEnd: \(reachedEnd)")
        }
    }
    
    @MainActor
    func resetState() {
        self.currentUser = nil
        self.currentUserImages = []
        self.isLoggedIn = false
    }
    
    private func getFilteredIds(for userId: String) async throws -> (Set<String>, Set<String>) {
        debugLog("🔎 Fetching filtered IDs for user \(userId)")
        
        async let dislikedDocs = db.collection("users").document(userId).collection("dislikes").getDocuments()
        async let likedDocs = db.collection("users").document(userId).collection("likes_sent").getDocuments()
        
        let (disliked, liked) = try await (dislikedDocs, likedDocs)
        
        debugLog("📋 Fetched \(disliked.documents.count) disliked IDs and \(liked.documents.count) liked IDs")
        
        return (Set(disliked.documents.map { $0.documentID }),
                Set(liked.documents.map { $0.documentID }))
    }
    
    
    
    @MainActor
    func checkProfileVisibility() -> Bool {
        !profileStack.isEmpty
    }
    
    @MainActor
    func isLoadingCurrentLevel() -> Bool {
        profileStack.isEmpty && !(moonLevelStacks[currentMoonLevel]?.isEmpty ?? true)
    }
    
    @MainActor
    func hasReachedEndForCurrentLevel() -> Bool {
        (moonLevelStacks[currentMoonLevel] ?? []).isEmpty
    }
    
    @MainActor
    private func removeUserFromAllStacks(userId: String) {
        debugLog("🗑️ Removing user \(userId) from all stacks")
        
        let beforeCounts = moonLevelStacks.mapValues { $0.count }
        
        for level in 0...4 {
            moonLevelStacks[level]?.removeAll { $0.id == userId }
        }
        
        let afterCounts = moonLevelStacks.mapValues { $0.count }
        
        debugLog("📊 Stack counts before removal: \(beforeCounts)")
        debugLog("📊 Stack counts after removal: \(afterCounts)")
        
        updateDisplayStack()
    }
    
    
    
    //======ONBOARDING FUNCS=======
    
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
                logUserLogin()
                print("✅ User successfully logged in and state updated")
                
                // Save authentication state
                UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
                UserDefaults.standard.set(authResult.user.uid, forKey: "lastLoggedInUserId")
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
                guard let imageData = image.jpegData(compressionQuality: 0.7) else { continue }
                
                let imagePath = "users/\(userId)/profile_\(index).jpg"
                let imageRef = storage.reference().child(imagePath)
                
                _ = try await imageRef.putDataAsync(imageData)
                let downloadURL = try await imageRef.downloadURL()
                pictureURLs.append(downloadURL.absoluteString)
            }
            
            print("✅ All images uploaded successfully")
            print("📸 URLs loaded: \(pictureURLs)")
            
            // 3. Create User object
            print("👤 Creating user object...")
            let newUser = User(
                id: userId,
                firstName: firstName,
                age: age,
                gender: gender,
                genderPreference: genderPreference,
                email: email,  // Make sure to include email here
                pictureURLs: pictureURLs,
                timesDisliked: 0,
                timesLiked: 0,
                minAgePreference: 18,
                maxAgePreference: 99,
                fcmToken: self.fcmToken
            )
            
            // 4. Create Firestore document
            print("📄 Creating Firestore document...")
            // Using Codable to automatically encode all fields, including email
            try await db.collection("users").document(userId).setData(from: newUser)
            logUserSignup(userAge: age, userGender: gender)
            print("✅ Firestore document created successfully")
            
            DispatchQueue.main.async {
                self.currentUser = newUser
                self.isLoggedIn = true
                
                UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
                UserDefaults.standard.set(userId, forKey: "lastLoggedInUserId")
                
                
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
    
    
    
    func signOut() async throws {
        if let userId = Auth.auth().currentUser?.uid {
            try await updateUserFCMToken(userId: userId, token: "")
        }
        do {
            logUserLogout()
            try Auth.auth().signOut()
            await MainActor.run {
                isLoggedIn = false
                currentUser = nil
                
                // Clear saved authentication state
                UserDefaults.standard.removeObject(forKey: "isUserLoggedIn")
                UserDefaults.standard.removeObject(forKey: "lastLoggedInUserId")
            }
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
            throw error
        }
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
    
    @objc private func updateFCMToken(_ notification: Notification) {
        print("📱 updateFCMToken called in ContentModel")
        if let token = notification.userInfo?["token"] as? String {
            print("🔄 Received new FCM token in ContentModel: \(token)")
            self.fcmToken = token
            // Don't try to update Firestore here - wait for explicit login
            print("💾 Token stored locally, waiting for user login")
        }
    }
    
    func updateUserSettings(images: [UIImage], minAge: Double, maxAge: Double, genderPreference: User.Gender) async throws {
        guard var updatedUser = currentUser else {
            throw NSError(domain: "ContentModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
        }
        
        let db = Firestore.firestore()
        let storage = Storage.storage()
        var pictureURLs: [String] = []
        
        // Upload new images
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                print("❌ Failed to convert image to data")
                continue
            }
            
            let imagePath = "users/\(updatedUser.id)/profile_\(index).jpg"
            let imageRef = storage.reference().child(imagePath)
            
            do {
                _ = try await imageRef.putDataAsync(imageData)
                let downloadURL = try await imageRef.downloadURL()
                pictureURLs.append(downloadURL.absoluteString)
                print("✅ Successfully uploaded image: \(downloadURL.absoluteString)")
            } catch {
                print("❌ Error uploading image: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Update user model
        updatedUser.pictureURLs = pictureURLs
        updatedUser.minAgePreference = Int(minAge)
        updatedUser.maxAgePreference = Int(maxAge)
        updatedUser.genderPreference = genderPreference
        
        // Update Firestore
        do {
            try await db.collection("users").document(updatedUser.id).updateData([
                "pictureURLs": pictureURLs,
                "minAgePreference": Int(minAge),
                "maxAgePreference": Int(maxAge),
                "genderPreference": genderPreference.rawValue
            ])
            print("✅ Successfully updated Firestore document")
        } catch {
            print("❌ Error updating Firestore document: \(error.localizedDescription)")
            throw error
        }
        
        // Update local state
        await MainActor.run {
            self.currentUser = updatedUser
            self.currentUserImages = images
            print("✅ Updated currentUser and currentUserImages")
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
    
    
    //=======PRELOADING==========
    
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
    
    func getPreloadedImage(for url: String) -> UIImage? {
        preloadedImages[url]
    }
    
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
    
    private func preloadImagesForUsers(_ users: [User]) async {
        await withTaskGroup(of: Void.self) { group in
            for user in users {
                group.addTask {
                    await self.preloadImagesForUser(user)
                }
            }
        }
    }
    
    //=======MATCHES AND MESSAGING========
    
    func fetchMatches() async throws {
        
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let matchDocs = try await db.collection("users")
            .document(currentUserId)
            .collection("matches")
            .getDocuments()
        
        var fetchedUsers: [(user: User, lastActivity: Date)] = []
        
        for matchDoc in matchDocs.documents {
            let match = try await db.collection("matches")
                .document(matchDoc.documentID)
                .getDocument()
            
            if let matchData = match.data(),
               let userIds = matchData["users"] as? [String],
               let lastActivity = matchData["lastActivity"] as? Timestamp {
                let matchedUserId = userIds.first { $0 != currentUserId } ?? ""
                
                let userDoc = try await db.collection("users")
                    .document(matchedUserId)
                    .getDocument()
                
                if let matchedUser = try? userDoc.data(as: User.self) {
                    fetchedUsers.append((user: matchedUser, lastActivity: lastActivity.dateValue()))
                }
            }
        }
        
        fetchedUsers.sort { $0.lastActivity > $1.lastActivity }
        let sortedUsers = fetchedUsers.map { $0.user }
        
        await MainActor.run {
            self.matches = sortedUsers
        }
        await preFetchMatchImages()
    }
    
    func sendMessage(to matchId: String, text: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Create the message object (timestamp is set locally in the Message initializer)
        let message = Message(senderId: currentUserId, text: text)
        
        // Log message sent (assuming this is a custom logging function)
        logMessageSent(matchId: matchId, messageLength: text.count)
        
        // Create a batch to update both the message and the match's lastActivity
        let batch = db.batch()
        
        // Add the message to the messages subcollection
        let messageRef = db.collection("matches")
            .document(matchId)
            .collection("messages")
            .document(message.id)
        batch.setData([
            "senderId": message.senderId,
            "text": message.text,
            "timestamp": message.timestamp // Use the local timestamp from the Message object
        ], forDocument: messageRef)
        
        // Update the lastActivity field in the match document to the server timestamp
        let matchRef = db.collection("matches").document(matchId)
        batch.updateData([
            "lastActivity": FieldValue.serverTimestamp() // Update lastActivity to the server timestamp
        ], forDocument: matchRef)
        
        // Commit the batch
        try await batch.commit()
        
        try await fetchMatches()
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
            print("✅ Refreshed current user. Picture URLs: \(userData.pictureURLs)")
        }
        
        // Preload the current user's images
        await preloadCurrentUserImages()
    }
    
    func deleteAccount(reason: String? = nil) async throws {
        logAccountDeletion(reason: reason)
        
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
        logSocialRequestSent(matchId: matchId)
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
        logDateRequestSent(matchId: matchId)
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
        let duration = await getMatchDuration(matchId)
        logUnmatch(matchId: matchId, matchDuration: duration, rating: rating)
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
    
    // ANALYTICS:
    
    func logUserSignup(userAge: Int, userGender: User.Gender) {
        Analytics.logEvent("user_signup", parameters: [
            "age": userAge,
            "gender": userGender.rawValue,
            "num_photos": currentUser?.pictureURLs.count ?? 0
        ])
    }
    
    func logUserLogin() {
        Analytics.logEvent("user_login", parameters: [
            "user_id": Auth.auth().currentUser?.uid ?? "",
            "has_matches": !matches.isEmpty
        ])
    }
    
    func logShareEvent(shareType: String) {
        Analytics.logEvent("user_share", parameters: [
            "share_type": shareType,
            "user_id": currentUser?.id ?? "unknown"
        ])
    }
    
    func logUserLogout() {
        Analytics.logEvent("user_logout", parameters: nil)
    }
    
    func logAccountDeletion(reason: String?) {
        Analytics.logEvent("account_deletion", parameters: [
            "reason": reason ?? "not_specified",
            "account_lifetime_days": daysSinceSignup()
        ])
    }
    
    
    func logUserLike(targetUserAge: Int, matchOccurred: Bool) {
        Analytics.logEvent("user_like", parameters: [
            "target_user_age": targetUserAge,
            "resulted_in_match": matchOccurred,
            "current_moon_level": currentMoonLevel
        ])
    }
    
    func logUserDislike(targetUserAge: Int) {
        Analytics.logEvent("user_dislike", parameters: [
            "target_user_age": targetUserAge,
            "current_moon_level": currentMoonLevel
        ])
    }
    
    func logMatchInteraction(matchId: String, interactionType: String) {
        Analytics.logEvent("match_interaction", parameters: [
            "match_id": matchId,
            "interaction_type": interactionType
        ])
    }
    
    
    func logMessageSent(matchId: String, messageLength: Int) {
        Analytics.logEvent("message_sent", parameters: [
            "match_id": matchId,
            "message_length": messageLength
        ])
    }
    
    func logUnmatch(matchId: String, matchDuration: TimeInterval, rating: Int) {
        Analytics.logEvent("unmatch", parameters: [
            "match_id": matchId,
            "match_duration_hours": matchDuration/3600,
            "final_rating": rating
        ])
    }
    
    
    func logSocialRequestSent(matchId: String) {
        Analytics.logEvent("social_request_sent", parameters: [
            "match_id": matchId
        ])
    }
    
    func logDateRequestSent(matchId: String) {
        Analytics.logEvent("date_request_sent", parameters: [
            "match_id": matchId
        ])
    }
    
    private func daysSinceSignup() -> Int {
        guard let creationDate = Auth.auth().currentUser?.metadata.creationDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
    }
    
    func getMatchDuration(_ matchId: String) async -> TimeInterval {
        do {
            let matchDoc = try await db.collection("matches").document(matchId).getDocument()
            
            // Get the match creation timestamp, defaulting to current time if not found
            guard let data = matchDoc.data(),
                  let timestamp = data["createdAt"] as? Timestamp else {
                return 0
            }
            
            return Date().timeIntervalSince(timestamp.dateValue())
        } catch {
            print("Error getting match duration: \(error)")
            return 0
        }
    }
    
}
