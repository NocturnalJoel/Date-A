//
//  NavigationBarView.swift
//  Date-A
//
//  Created by Joël Lacoste-Therrien on 2024-11-10.
//

import SwiftUI

struct NavigationBarView: View {
    @EnvironmentObject var model: ContentModel
    @State private var showingSettings = false
    @State private var showingMatches = false
    var body: some View {
            HStack {
                // Settings Button - Using navigation state instead of NavigationLink
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // App Logo
                Text("DATE-A")
                    .font(.system(size: 34, weight: .heavy))  // .heavy au lieu de .bold pour plus d'épaisseur
                    .tracking(-1.5)  // Valeur négative pour rapprocher les lettres
                    .kerning(-0.8)   // Ajustement supplémentaire de l'espacement
                    .scaleEffect(x: 1.1, y: 1.0)
                
                Spacer()
                
                // Matches Button - Using navigation state instead of NavigationLink
                Button {
                    showingMatches = true
                } label: {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            // Use navigation destinations instead of NavigationLink
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .navigationDestination(isPresented: $showingMatches) {
                MatchesView()
                    .environmentObject(model)
            }
        }
}

