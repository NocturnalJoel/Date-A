// User.swift
import Foundation

struct User: Identifiable, Codable, Equatable {
    var id: String
    var firstName: String
    var age: Int
    var gender: Gender
    var genderPreference: Gender
    var email: String
    var pictureURLs: [String]
    var timesDisliked: Int
    var timesLiked: Int
    var minAgePreference: Int 
    var maxAgePreference: Int
    var fcmToken: String?

    
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }
}

struct Message: Identifiable, Codable {
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

