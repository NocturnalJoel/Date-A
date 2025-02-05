import SwiftUI
import FirebaseAuth
import FirebaseFirestore



struct ImageGalleryView: View {
    let urls: [String]
    @Binding var isPresented: Bool
    @State private var selectedIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @EnvironmentObject var model: ContentModel
    @State private var cachedImages: [Int: UIImage] = [:]

    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Black background
            Color.black.ignoresSafeArea()
            
            // Image gallery
            TabView(selection: $selectedIndex) {
                ForEach(Array(urls.enumerated()), id: \.0) { index, url in
                    ZStack {
                        if let image = cachedImages[index] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .tag(index)
                                .modifier(ImageModifier())
                        } else {
                            Color.gray.opacity(0.3)
                                .task {
                                    await loadImage(url: url, forIndex: index)
                                }
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            
            // Close button
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .zIndex(2)
        }
        .task {
            // Pre-load the first image if it's in the cache
            if let url = urls.first,
               let image = model.imageCache.object(forKey: url as NSString) {
                cachedImages[0] = image
            }
        }
    }
    
    private func loadImage(url: String, forIndex index: Int) async {
        // First check the cache
        if let cachedImage = model.imageCache.object(forKey: url as NSString) {
            cachedImages[index] = cachedImage
            return
        }
        
        guard let imageUrl = URL(string: url) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            if let image = UIImage(data: data) {
                cachedImages[index] = image
                model.imageCache.setObject(image, forKey: url as NSString)
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
}

// ImageModifier for zoom functionality
struct ImageModifier: ViewModifier {
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    scale = scale * delta
                }
                .onEnded { value in
                    lastScale = 1.0
                    if scale < 1.0 {
                        withAnimation {
                            scale = 1.0
                        }
                    } else if scale > 3.0 {
                        withAnimation {
                            scale = 3.0
                        }
                    }
                }
            )
            .gesture(TapGesture(count: 2).onEnded {
                if scale > 1.0 {
                    withAnimation {
                        scale = 1.0
                    }
                } else {
                    withAnimation {
                        scale = 2.0
                    }
                }
            })
    }
}

// ChatView.swift
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
    @State private var cachedImage: UIImage?
    @State private var showingGallery = false
    @State private var showingReportSheet = false
    
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
                    if let image = cachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .onTapGesture {
                                showingGallery = true
                            }
                    } else {
                        Color.gray.opacity(0.1)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .task {
                                // Fallback loading if somehow the image wasn't pre-fetched
                                if let url = URL(string: imageURL),
                                   let (data, _) = try? await URLSession.shared.data(from: url),
                                   let loadedImage = UIImage(data: data) {
                                    cachedImage = loadedImage
                                    // Store in cache for future use
                                    model.imageCache.setObject(loadedImage, forKey: imageURL as NSString)
                                }
                            }
                    }
                }
                
                Text(matchedUser.firstName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button {
                    showingManageSheet = true
                } label: {
                    ZStack {
                        Capsule()
                            .foregroundColor(Color.black.opacity(0.5))
                        Text("Manage")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 40)
                }
                .padding(.trailing, 4)
                .buttonStyle(.plain)
                
                Button {
                    showingReportSheet = true
                } label: {
                    ZStack {
                        Capsule()
                            .foregroundColor(Color.red.opacity(0.8))
                        HStack(spacing: 4) {
                            Text("Report")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
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
            // Try to get cached image first
            if let imageURL = matchedUser.pictureURLs.first,
               let image = model.imageCache.object(forKey: imageURL as NSString) {
                cachedImage = image
            }
            
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
        .fullScreenCover(isPresented: $showingGallery) {
            ImageGalleryView(
                urls: matchedUser.pictureURLs,
                isPresented: $showingGallery
            )
            .environmentObject(model)
        }
        .sheet(isPresented: $showingManageSheet) {
                    // This closure is called after the sheet is dismissed
                    Task {
                        try? await model.fetchMessages(for: matchId)
                    }
                } content: {
                    ManageMatchView(shouldPopToRoot: $shouldPopToRoot, matchId: matchId)
                }
        .sheet(isPresented: $showingReportSheet) {
            ReportView(
                shouldPopToRoot: $shouldPopToRoot,
                matchId: matchId,
                matchedUser: matchedUser
            )
        }
        .onChange(of: shouldPopToRoot) { newValue in
            if newValue {
                dismiss()
            }
        }
    }
}
