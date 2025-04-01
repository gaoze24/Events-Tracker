//
//  ContentView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 24/3/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedItem: String? = "Home"
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Text("Home").tag("Home").font(.title2).padding(.vertical, 3)
                Text("Events").tag("Events").font(.title2)
                    .padding(.vertical, 3)
                Text("Profile").tag("Profile").font(.title2)
                    .padding(.vertical, 3)
                Text("Settings").tag("Settings").font(.title2)
                    .padding(.vertical, 3)
            }
            .frame(minWidth: 200, idealWidth: 200, maxWidth: 250)
            .navigationTitle("Menu")
        } detail: {
            switch selectedItem {
                case "Home":
                HomeView()
                case "Events":
                EventsView()
            case "Profile":
                ProfileView()
            case "Settings":
                SettingsView()
            default:
                HomeView()
            }
        }
    }
}

#Preview {
    ContentView()
}
