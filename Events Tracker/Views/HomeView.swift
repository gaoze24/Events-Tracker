//
//  HomeView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct HomeView: View {
    @State private var courses: [Course] = []

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 24) {
                Section(header: Text("Your Courses")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)) {
                        ForEach(courses, id: \.id) { course in
                            Button(action: {
                                // handle course selection
                            }) {
                                Text(course.name)
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
                        // Placeholder for upcoming events
                        ForEach(courses) { assignment in
                            Button(action: {
                                // handle assignment selection
                            }) {
                                HStack {
                                    Text("\(assignment)")
                                        .bold()
                                    Spacer()
                                    Text("\(assignment)")
                                        .foregroundColor(.red)
                                }
                                .padding()
                            }
                        }
                    }
            }
        }
        .padding()
        .onAppear(perform: loadCourses)
    }

    private func loadCourses() {
        self.courses = DatabaseManager.shared.loadCourses()
        fetchCourses()
    }

    private func fetchCourses() {
        NetworkManager.shared.fetchCourses { result in
            switch result {
            case .success(let courses):
                DispatchQueue.main.async {
                    self.courses = courses
                }
            case .failure(let error):
                print("Failed to fetch courses: \(error)")
            }
        }
    }
}

#Preview {
    HomeView()
}
