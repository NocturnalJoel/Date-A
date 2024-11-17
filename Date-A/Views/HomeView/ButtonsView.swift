//
//  ButtonsView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct ButtonsView: View {

    @EnvironmentObject var model: ContentModel

    var body: some View {
        HStack(spacing: 40) {
            // Dislike Button
            Button(action: {
                if let currentProfile = model.currentProfile {
                        Task {
                            try? await model.dislikeUser(currentProfile)
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
            
            // Like Button
            Button(action: {
                if let currentProfile = model.currentProfile {
                        Task {
                            try? await model.likeUser(currentProfile)
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
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
    }
}

