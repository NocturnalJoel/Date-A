//
//  ButtonsView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct ButtonsView: View {
    @EnvironmentObject var model: ContentModel
    @State private var likeError: Error?
    @State private var showError = false

    var body: some View {
        HStack(spacing: 40) {
            // Dislike Button
            Button(action: {
                guard !model.profileStack.isEmpty else { return }
                                let topProfile = model.profileStack[0]
                                
                                Task {
                                    do {
                                        try await model.dislikeUser(topProfile)
                                    } catch {
                                        print("Dislike error: \(error)")
                                        likeError = error
                                        showError = true
                                    }
                                }
            }) {
                Image(systemName: "xmark")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .buttonStyle(.plain)
            
            // Like Button
            Button(action: {
                guard !model.profileStack.isEmpty else { return }
                                let topProfile = model.profileStack[0]
                                
                                Task {
                                    do {
                                        try await model.likeUser(topProfile)
                                    } catch {
                                        print("Like error: \(error)")
                                        likeError = error
                                        showError = true
                                    }
                                }
            }) {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(likeError?.localizedDescription ?? "Unknown error occurred")
        }
    }
}
