// Date_AApp.swift
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import Photos

@main
struct Date_AApp: App {
    @StateObject private var model = ContentModel()
    
    // Add this to handle notifications
    class AppDelegate: NSObject, UIApplicationDelegate {
        let gcmMessageIDKey = "gcm.message_id"
        
        func application(_ application: UIApplication,
                        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
            
            Messaging.messaging().delegate = self
            
            // Request permission for notifications
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )
            
            application.registerForRemoteNotifications()
            
            return true
        }
        
        // Handle device token
        func application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Messaging.messaging().apnsToken = deviceToken
        }
        
        func application(_ application: UIApplication,
                        didFailToRegisterForRemoteNotificationsWithError error: Error) {
            print("Failed to register for notifications: \(error.localizedDescription)")
        }
    }
    
    // Add Firebase Messaging delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    init() {
        FirebaseApp.configure()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        model.permissionGranted = (status == .authorized || status == .limited)
    }
    
    var body: some Scene {
        WindowGroup {
            
           
            NavigationView {
                
                // Add this
                Group {
                    if let user = model.currentUser {
                        HomeView()
                            .environmentObject(model)
                            .preferredColorScheme(.light)
                    } else {
                        FirstView()
                            .environmentObject(model)
                            .preferredColorScheme(.light)
                    }
                }
            }
            .onAppear {
                model.checkAuthStatus()
            }
            
            
        }
    }
    
}
extension Date_AApp.AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: tokenDict)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension Date_AApp.AppDelegate: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 or later
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
                              -> Void) {
        let userInfo = notification.request.content.userInfo
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Show notification banner even when app is in foreground
        completionHandler([[.banner, .badge, .sound]])
    }
    
    // Handle notification response
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        completionHandler()
    }
}
