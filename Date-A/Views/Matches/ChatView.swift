import SwiftUI
import FirebaseAuth

struct ChatView: View {
    let matchedUser: User
    let matchId: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ContentModel
    @State private var messageText = ""
    @State private var isLoading = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                
                if let imageURL = matchedUser.pictureURLs.first {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.1)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                }
                
                Text(matchedUser.firstName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
            
            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.messages) { message in
                        MessageBubble(message: message, isSender: message.senderId == Auth.auth().currentUser?.uid)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Message", text: $messageText)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .focused($isFocused)
                
                Button {
                    Task {
                        let text = messageText
                        messageText = ""
                        try? await model.sendMessage(to: matchId, text: text)
                        try? await model.fetchMessages(for: matchId)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(messageText.isEmpty ? .gray : .black)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(Color.white)
        }
        .navigationBarHidden(true)
        .task {
            isLoading = true
            try? await model.fetchMessages(for: matchId)
            isLoading = false
        }
    }
}
