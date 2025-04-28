//
//  Models.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import Foundation
import SwiftData

@Model
final class Quiz {
    var id: UUID
    var title: String
    var createdAt: Date
    var questions: [Question]? // Relationship to Question entities
    var userId: String
    
    init(title: String, userId: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.userId = userId
    }
}

@Model
final class Question {
    var id: UUID
    var quiz: Quiz? // Relationship to parent Quiz
    var questionText: String
    var questionType: QuestionType
    var options: [String]? // For multiple choice
    var correctAnswer: String
    var explanation: String?
    
    init(questionText: String, questionType: QuestionType, correctAnswer: String) {
        self.id = UUID()
        self.questionText = questionText
        self.questionType = questionType
        self.correctAnswer = correctAnswer
    }
}

enum QuestionType: String, Codable {
    case multipleChoice
    case fillInBlank
    case longAnswer
}
