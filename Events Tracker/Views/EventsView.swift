//
//  EventsView.swift
//  Events Tracker
//
//  Created by Eddie Gao on 31/3/25.
//

import SwiftUI

struct EventsView: View {
    @State private var assignments: [Assignment] = []
    @State private var selectedCourse: Course?

    var body: some View {
        VStack {
            if let selectedCourse = selectedCourse {
                List(assignments) { assignment in
                    VStack(alignment: .leading) {
                        Text(assignment.name)
                        let dueAt = assignment.dueAt
                        if dueAt == assignment.dueAt {
                            Text("Due: \(dueAt)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .navigationTitle(selectedCourse.name)
            } else {
                Text("Select a course")
                    .foregroundColor(.gray)
            }
        }
        .onAppear(perform: loadCourses)
    }

    private func loadCourses() {
        let savedCourses = DatabaseManager.shared.loadCourses()
        if let firstCourse = savedCourses.first {
            self.selectedCourse = firstCourse
            loadAssignments(for: firstCourse)
        } else {
            fetchCourses()
        }
    }

    private func fetchCourses() {
        NetworkManager.shared.fetchCourses { result in
            switch result {
            case .success(let courses):
                DispatchQueue.main.async {
                    if let firstCourse = courses.first {
                        self.selectedCourse = firstCourse
                        fetchAssignments(for: firstCourse)
                    }
                }
            case .failure(let error):
                print("Failed to fetch courses: \(error)")
            }
        }
    }

    private func loadAssignments(for course: Course) {
        self.assignments = DatabaseManager.shared.loadAssignments(for: course.id)
        fetchAssignments(for: course)
    }

    private func fetchAssignments(for course: Course) {
        NetworkManager.shared.fetchAssignments(courseID: course.id) { result in
            switch result {
            case .success(let assignments):
                DispatchQueue.main.async {
                    self.assignments = assignments
                }
            case .failure(let error):
                print("Failed to fetch assignments: \(error)")
            }
        }
    }
}

#Preview {
    EventsView()
}
