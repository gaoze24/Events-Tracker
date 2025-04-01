//
//  DatabaseManager.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?

    private let coursesTable = Table("courses")
    private let assignmentsTable = Table("assignments")

    private let id = Expression<Int>(value: 0)
    private let name = Expression<String>(value: "")
    private let dueAt = Expression<String?>(value: "")
    private let courseID = Expression<Int>(value: 0)

    private init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/db.sqlite3")
            createTables()
        } catch {
            print("Unable to open database. Error: \(error)")
        }
    }

    private func createTables() {
        do {
            try db?.run(coursesTable.create(ifNotExists: true) { table in
                table.column(id, primaryKey: true)
                table.column(name)
            })

            try db?.run(assignmentsTable.create(ifNotExists: true) { table in
                table.column(id, primaryKey: true)
                table.column(name)
                table.column(dueAt)
                table.column(courseID)
            })
        } catch {
            print("Unable to create tables. Error: \(error)")
        }
    }

    func saveCourses(_ courses: [Course]) {
        do {
            for course in courses {
                try db?.run(coursesTable.insert(or: .replace, id <- course.id, name <- course.name))
            }
        } catch {
            print("Unable to save courses. Error: \(error)")
        }
    }

    func saveAssignments(_ assignments: [Assignment], for courseID: Int) {
        do {
            for assignment in assignments {
                try db?.run(assignmentsTable.insert(or: .replace, id <- assignment.id, name <- assignment.name, dueAt <- assignment.dueAt, self.courseID <- courseID))
            }
        } catch {
            print("Unable to save assignments. Error: \(error)")
        }
    }

    func loadCourses() -> [Course] {
        var courses = [Course]()
        do {
            for course in try db!.prepare(coursesTable) {
                courses.append(Course(id: course[id], name: course[name]))
            }
        } catch {
            print("Unable to load courses. Error: \(error)")
        }
        return courses
    }

    func loadAssignments(for courseID: Int) -> [Assignment] {
        var assignments = [Assignment]()
        do {
            let query = assignmentsTable.filter(self.courseID == courseID)
            for assignment in try db!.prepare(query) {
                assignments.append(Assignment(id: assignment[id], name: assignment[name], dueAt: assignment[dueAt]))
            }
        } catch {
            print("Unable to load assignments. Error: \(error)")
        }
        return assignments
    }
}
