//
//  Date_AApp.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-01.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import Photos

@main
struct Date_AApp: App {
    
    @StateObject private var model = ContentModel()
    
    init() {
        FirebaseApp.configure()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        model.permissionGranted = (status == .authorized || status == .limited)
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {  // Add this
                Group {
                    if let user = model.currentUser {
                        HomeView()
                            .environmentObject(model)
                    } else {
                        OnboardingView()
                            .environmentObject(model)
                    }
                }
            }
            .onAppear {
                model.checkAuthStatus()
            }
        }
    }
    
}
