//
//  HomeView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct HomeView: View {
    // Mock data
    let courses = ["MA1511", "CS1010", "EG1311"]
    let upcomings = [("E1", 1), ("E2", 2), ("E3", 3)]
    
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 24) {
                Section(header: Text("Your Courses")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)) {
                        ForEach(courses, id: \.self) { course in
                            Button(action: {
                                // handle course selection
                            }) {
                                Text(course)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            }
                        }
                    }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 24) {
                Section(header: Text("Upcoming Events")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)) {
                        ForEach(upcomings, id: \.0) { assignment in
                            Button(action: {
                                // handle assignment selection
                            }) {
                                HStack {
                                    Text("\(assignment.0)")
                                        .bold()
                                    Spacer()
                                    Text("\(assignment.1)")
                                        .foregroundColor(.red)
                                }
                                .padding()
                            }
                        }
                    }
            }
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
