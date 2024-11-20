import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isSender: Bool
    
    var body: some View {
        HStack {
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
