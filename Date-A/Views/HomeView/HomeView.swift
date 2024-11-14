//
//  HomeView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var model: ContentModel
    
    @State private var offset: CGFloat = 0

    // Sample user for preview
    let sampleUser = User(
        id: "1",
        firstName: "Emma",
        age: 28,
        gender: .female,
        genderPreference: .male,
        email: "emma@example.com",
        pictureURLs: [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg",
            "https://example.com/photo3.jpg"
        ],
        timesShown: 0,
        timesLiked: 0,
        minAgePreference: 18,
        maxAgePreference: 99
    )
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationBarView()
                    .environmentObject(model)
                
                MoonSliderView()
                    .environmentObject(model)
                
                Spacer()
                //
                ZStack {
                                    if model.isLoadingProfiles && model.currentProfile == nil {
                                        ProgressView()
                                        
                                    } else if model.currentProfile == nil && model.nextProfile == nil {
                                            // No profiles available state
                                            VStack(spacing: 16) {
                                                Image(systemName: "person.slash")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(.gray)
                                                
                                                Text("No More Profiles Available")
                                                    .font(.title3)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.gray)
                                                
                                                Text("Check back later for new matches")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray.opacity(0.8))
                                            }
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.white.opacity(0.9))
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .shadow(radius: 5)
                                        
                                    } else {
                                        if let nextProfile = model.nextProfile {
                                            ProfileCardView(user: nextProfile)
                                        }
                                        if let currentProfile = model.currentProfile {
                                            ProfileCardView(user: currentProfile)
                                                .offset(x: offset)
                                                .zIndex(1)
                                        }
                                    }
                                }
                //
                Spacer()
                
                ButtonsView()
                    .environmentObject(model)
            }
            .navigationBarHidden(true)
            //
            .onAppear { model.startFetchingProfiles() }
            //
        }
    }
}

#Preview {
    HomeView()
}
