import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import Photos

@main
struct Date_AApp: App {
    @StateObject private var model = ContentModel()
    
    class AppDelegate: NSObject, UIApplicationDelegate {
        let gcmMessageIDKey = "gcm.message_id"
        
        func application(_ application: UIApplication,
                        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
            print("🚀 AppDelegate didFinishLaunching")
            
            // Set messaging delegate before requesting permissions
            Messaging.messaging().delegate = self
            
            // Request permission for notifications
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { granted, error in
                    print("🔔 Notification permission granted: \(granted)")
                    if let error = error {
                        print("❌ Notification permission error: \(error)")
                    }
                }
            )
            
            application.registerForRemoteNotifications()
            return true
        }
        
        func application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            print("📱 Received device token")
            Messaging.messaging().apnsToken = deviceToken
        }
    }
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        FirebaseApp.configure()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        model.permissionGranted = (status == .authorized || status == .limited)
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
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
        }
    }
}

// MARK: - MessagingDelegate
extension Date_AApp.AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("⭐️ Firebase registration token received: \(String(describing: fcmToken))")
        
        if let token = fcmToken {
            let tokenDict = ["token": token]
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: tokenDict)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension Date_AApp.AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
                              -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 Received notification while app in foreground")
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("📨 Message ID: \(messageID)")
        }
        
        completionHandler([[.banner, .badge, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification")
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("📨 Message ID: \(messageID)")
        }
        
        completionHandler()
    }
}
