//
//  RatingPopupView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-12-28.
//

import SwiftUI

struct RatingPopupView: View {
    @Binding var isPresented: Bool
    let matchId: String
    let onSubmit: (Int) async -> Void
    
    @State private var selectedRating: Int = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Rate Conversation")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Text("How would you rate the quality of your conversation?")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.title2)
                            .onTapGesture {
                                withAnimation {
                                    selectedRating = star
                                }
                            }
                    }
                }
                .padding(.vertical)
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                    .buttonStyle(.plain)
                    
                    Button{
                        Task {
                            await onSubmit(selectedRating)
                            isPresented = false
                        }
                    }label:{
                        
                        ZStack {
                            
                            Capsule()
                                .foregroundColor(Color.red.opacity(0.8))
                                
                            
                            Text("Submit")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                    }
                    .frame(width: 100, height: 40)
                    .disabled(selectedRating == 0)
                    .buttonStyle(.plain)
                    
                    
                    
                    
                    
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
        }
    }
}
