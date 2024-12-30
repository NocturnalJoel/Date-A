import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    let matchedUser: User
    let matchId: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ContentModel
    @State private var messageText = ""
    @State private var isLoading = false
    @FocusState private var isFocused: Bool
    @State private var shouldPopToRoot = false
    
    @State private var showingManageSheet = false
    
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
                .buttonStyle(.plain)
                
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
                
                Button{
                    showingManageSheet = true
                }label:{
                    ZStack{
                        Capsule()
                            .foregroundColor(Color.black.opacity(0.5))
                        Text("Manage")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 40)
                }
                .padding(.trailing)
                .buttonStyle(.plain)
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
            
            try? await Firestore.firestore()
                    .collection("matches")
                    .document(matchId)
                    .updateData([
                        "viewed.\(Auth.auth().currentUser?.uid ?? "")": FieldValue.serverTimestamp()
                    ])
            
            
            isLoading = false
        }
        .sheet(isPresented: $showingManageSheet) {
                    ManageMatchView(shouldPopToRoot: $shouldPopToRoot, matchId: matchId)
                }
                .onChange(of: shouldPopToRoot) { newValue in
                    if newValue {
                        dismiss()
                    }
                }
    }
}
