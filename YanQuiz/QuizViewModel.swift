//
//  QuizViewModel.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import Foundation
import SwiftUI
import Combine

class QuizViewModel: ObservableObject {
    @Published var currentQuiz: Quiz?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkService = NetworkService()
    
    func uploadPDF(fileURL: URL, userId: String) {
        isLoading = true
        
        Task {
            do {
                let quiz = try await networkService.uploadPDF(fileURL: fileURL, userId: userId)
                await MainActor.run {
                    self.currentQuiz = quiz
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func evaluateAnswer(question: Question, userAnswer: String) async throws -> AnswerEvaluation {
        switch question.questionType {
        case .multipleChoice:
            // Simple comparison for multiple choice
            let isCorrect = userAnswer.lowercased() == question.correctAnswer.lowercased()
            return AnswerEvaluation(
                isCorrect: isCorrect,
                feedback: isCorrect ? "Correct!" : "Incorrect. The correct answer was \(question.correctAnswer).",
                score: isCorrect ? 1.0 : 0.0
            )
            
        case .fillInBlank:
            // Case insensitive comparison
            let isCorrect = userAnswer.lowercased() == question.correctAnswer.lowercased()
            return AnswerEvaluation(
                isCorrect: isCorrect,
                feedback: isCorrect ? "Correct!" : "Incorrect. The correct answer was \(question.correctAnswer).",
                score: isCorrect ? 1.0 : 0.0
            )
            
        case .longAnswer:
            // Server-side evaluation
            return try await networkService.evaluateLongAnswer(questionId: question.id, userAnswer: userAnswer)
        }
    }
}
