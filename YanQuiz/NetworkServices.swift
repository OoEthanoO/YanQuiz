//
//  NetworkServices.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import Foundation
import SwiftUI

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case serverError(String)
    case authError
    case noData
    case unknown
}

class NetworkService {
    
    
    private var baseURL: String {
        let useDevServer = UserDefaults.standard.bool(forKey: "use_development_server")
        if useDevServer {
            return "http://localhost:3000/api"
        } else {
            return "https://yanquiz.onrender.com/api"
        }
    }
    
    static let shared = NetworkService()
    var authToken: String?
    
    func restoreAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Authentication
    
    func loginUser(email: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/login"
        
        // Prepare login credentials
        let credentials = ["email": email, "password": password]
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(credentials)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.authError
            } else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        do {
            let responseBody = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.authToken = responseBody.token
            return responseBody.user
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    func registerUser(email: String, password: String, name: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/register"
        
        // Prepare registration data
        let userData = ["email": email, "password": password, "name": name]
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(userData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 409 {
                throw NetworkError.serverError("Email already exists")
            } else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        do {
            let responseBody = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.authToken = responseBody.token
            return responseBody.user
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    func logout() {
        // Clear authentication token
        self.authToken = nil
    }
    
    // MARK: - PDF Upload and Quiz Generation
    
    func uploadPDF(fileURL: URL, userId: String) async throws -> Quiz {
        let endpoint = "\(baseURL)/quizzes/generate"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        // Create form data with PDF file
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        guard let authToken = self.authToken else {
            throw NetworkError.authError
        }
        
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var formData = Data()
        
        // Add user ID
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(userId)".data(using: .utf8)!)
        
        // Add PDF file
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"pdfFile\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        
        // Read PDF file data
        let pdfData = try Data(contentsOf: fileURL)
        formData.append(pdfData)
        formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.authError
            } else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        do {
            let quizResponse = try JSONDecoder().decode(QuizResponse.self, from: data)
            
            // Create SwiftData model objects
            let quiz = Quiz(title: quizResponse.title, userId: userId)
            quiz.id = UUID(uuidString: quizResponse.id) ?? UUID()
            
            var questions: [Question] = []
            
            for questionData in quizResponse.questions {
                let question = Question(
                    questionText: questionData.questionText,
                    questionType: QuestionType(rawValue: questionData.questionType) ?? .multipleChoice,
                    correctAnswer: questionData.correctAnswer
                )
                question.id = UUID(uuidString: questionData.id) ?? UUID()
                question.explanation = questionData.explanation
                question.options = questionData.options
                question.quiz = quiz
                
                questions.append(question)
            }
            
            quiz.questions = questions
            
            return quiz
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    // MARK: - Long Answer Evaluation
    
    func evaluateLongAnswer(questionId: UUID, userAnswer: String) async throws -> AnswerEvaluation {
        let endpoint = "\(baseURL)/quizzes/evaluate"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let evaluationRequest = [
            "questionId": questionId.uuidString,
            "answer": userAnswer
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let authToken = self.authToken else {
            throw NetworkError.authError
        }
        
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(evaluationRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.authError
            } else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        do {
            return try JSONDecoder().decode(AnswerEvaluation.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    // MARK: - Quiz Management
    
    func fetchUserQuizzes(userId: String) async throws -> [Quiz] {
        let endpoint = "\(baseURL)/quizzes/user/\(userId)"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let authToken = self.authToken else {
            throw NetworkError.authError
        }
        
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.authError
            } else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        do {
            let quizResponses = try JSONDecoder().decode([QuizResponse].self, from: data)
            
            var quizzes: [Quiz] = []
            
            for quizData in quizResponses {
                let quiz = Quiz(title: quizData.title, userId: userId)
                quiz.id = UUID(uuidString: quizData.id) ?? UUID()
                
                var questions: [Question] = []
                
                for questionData in quizData.questions {
                    let question = Question(
                        questionText: questionData.questionText,
                        questionType: QuestionType(rawValue: questionData.questionType) ?? .multipleChoice,
                        correctAnswer: questionData.correctAnswer
                    )
                    question.id = UUID(uuidString: questionData.id) ?? UUID()
                    question.explanation = questionData.explanation
                    question.options = questionData.options
                    question.quiz = quiz
                    
                    questions.append(question)
                }
                
                quiz.questions = questions
                quizzes.append(quiz)
            }
            
            return quizzes
        } catch {
            throw NetworkError.decodingError
        }
    }
}

// MARK: - API Response Models

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct QuizResponse: Codable {
    let id: String
    let title: String
    let questions: [QuestionResponse]
}

struct QuestionResponse: Codable {
    let id: String
    let questionText: String
    let questionType: String
    let options: [String]?
    let correctAnswer: String
    let explanation: String?
}

struct AnswerEvaluation: Codable {
    let isCorrect: Bool
    let feedback: String
    let score: Double // 0-1 for partial credit
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    var name: String?
}
