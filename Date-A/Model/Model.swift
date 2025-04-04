// User.swift
import Foundation

struct User: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var firstName: String
    var age: Int
    var gender: Gender
    var genderPreference: Gender
    var email: String  // This field is already present
    var pictureURLs: [String]
    var timesDisliked: Int
    var timesLiked: Int
    var minAgePreference: Int
    var maxAgePreference: Int
    var fcmToken: String?
    var likeRatio: Double
    var approachLine: String?
    
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }
    
    init(id: String,
         firstName: String,
         age: Int,
         gender: Gender,
         genderPreference: Gender,
         email: String,
         pictureURLs: [String],
         timesDisliked: Int = 0,
         timesLiked: Int = 0,
         minAgePreference: Int = 18,
         maxAgePreference: Int = 99,
         fcmToken: String? = nil,
         approachLine: String? = nil) {  // Add this parameter with default empty string
        self.id = id
        self.firstName = firstName
        self.age = age
        self.gender = gender
        self.genderPreference = genderPreference
        self.email = email
        self.pictureURLs = pictureURLs
        self.timesDisliked = timesDisliked
        self.timesLiked = timesLiked
        self.minAgePreference = minAgePreference
        self.maxAgePreference = maxAgePreference
        self.fcmToken = fcmToken
        self.likeRatio = Self.calculateInitialRatio(timesLiked: timesLiked, timesDisliked: timesDisliked)
        self.approachLine = approachLine  // Add this initialization
    }
    
    private static func calculateInitialRatio(timesLiked: Int, timesDisliked: Int) -> Double {
        let total = timesLiked + timesDisliked
        if total == 0 || timesLiked == 0 || timesDisliked == 0 {
            return 50.0
        }
        return (Double(timesLiked) / Double(total)) * 100
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, senderId: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
    }
}

enum StampType {
    case like
    case dislike
}
