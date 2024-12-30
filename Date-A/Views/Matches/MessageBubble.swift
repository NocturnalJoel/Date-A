import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isSender: Bool
    
    private var isSystemMessage: Bool {
        message.senderId == "system"
    }
    
    var body: some View {
        HStack {
            if isSystemMessage {
                Spacer()
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))  // Light blue background
                    .foregroundColor(Color.blue.opacity(0.8))  // Darker blue text
                    .font(.system(size: 14))
                    .cornerRadius(16)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                if isSender { Spacer() }
                
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isSender ? Color.black : Color.gray.opacity(0.1))
                    .foregroundColor(isSender ? .white : .black)
                    .cornerRadius(20)
                    .textSelection(.enabled)
                
                if !isSender { Spacer() }
            }
        }
    }
}
