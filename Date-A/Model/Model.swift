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
    var timesShown: Int
    var timesLiked: Int
    var minAgePreference: Int 
    var maxAgePreference: Int
    
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }
}

