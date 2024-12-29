//  HomeView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//
import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var model: ContentModel
    
    @State private var matchedUser: User?
    @State private var showMatchAnimation = false
    // Sample user for preview
    
    
    var body: some View {
        NavigationStack {
       
                
               
                
                VStack(spacing: 0) {
                    NavigationBarView()
                        .environmentObject(model)
                    
                    MoonSliderView(selectedLevel: $model.moonSliderLevel)
                        .environmentObject(model)
                    
                    Spacer()
                    //
                    ZStack {
                        
                        
                        
                        
                        
                        if !model.profileStack.isEmpty {
                            // Show background cards without animation
                            ForEach(Array(model.profileStack.enumerated().reversed()), id: \.element.id) { _, user in
                                ProfileCardView(
                                    user: user // Stack always stays centered
                                )
                                
                            }
                            
                        } else {
                            // Only show this if we truly have no profiles
                            if model.isLoadingProfiles {
                                ProgressView()
                            } else {
                                VStack(spacing: 16) {
                                    Text("🌌")
                                        .font(.system(size: 150, weight: .bold))
                                    
                                    
                                    Text("The Sky Is Empty Tonight")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                    
                                    Text("Change your filters to see more profiles")
                                        .font(.subheadline)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(radius: 5)
                                .padding()
                            }
                        }
                    }
                    .frame(height: 500)
                    //
                    Spacer()
                    
                    ButtonsView(showMatchAnimation: $showMatchAnimation, matchedUser: $matchedUser)
                    .environmentObject(model)
                }
                .navigationBarHidden(true)
                .overlay(
                    ZStack {
                                        if showMatchAnimation, let matchedUser = matchedUser {
                                            MatchAnimationView(isPresented: $showMatchAnimation, matchedUser: matchedUser)
                                        }
                                    }

                            )                .onAppear {
                    
                    model.startFetchingProfiles()
                    Task {
                            do {
                                await model.loadUnmatchedProfiles()
                                try await model.fetchMatches()
                            } catch {
                                // Handle the error appropriately
                                print("Error fetching matches: \(error)")
                            }
                        }
                    
                }
                
            
        }
    }
    
    
}
