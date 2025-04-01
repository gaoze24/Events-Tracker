//
//  NetworkManager.swift
//  Events Tracker
//
//  Created by Eddie Gao on 1/4/25.
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() { }
    
    func fetchCourses(completion: @escaping (Result<[Course], Error>) -> Void) {
        do {
            let config = try CanvasConfigManager.shared.loadConfig()
            guard let url = URL(string: "\(config.baseURL)") else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                    return
                }
                do {
                    let courses = try JSONDecoder().decode([Course].self, from: data)
                    DatabaseManager.shared.saveCourses(courses)
                    completion(.success(courses))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }
    
    func fetchAssignments(courseID: Int, completion: @escaping (Result<[Assignment], Error>) -> Void) {
        do {
            let config = try CanvasConfigManager.shared.loadConfig()
            guard let url = URL(string: "\(config.baseURL)") else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                    return
                }
                do {
                    let assignments = try JSONDecoder().decode([Assignment].self, from: data)
                    DatabaseManager.shared.saveAssignments(assignments, for: courseID)
                    completion(.success(assignments))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }
}
