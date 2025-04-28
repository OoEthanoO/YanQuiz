//
//  QuizListView.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import SwiftUI
import SwiftData

struct QuizListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var quizzes: [Quiz]
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var quizToDelete: Quiz?
    
    var filteredQuizzes: [Quiz] {
        if searchText.isEmpty {
            return quizzes
        } else {
            return quizzes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if quizzes.isEmpty {
                    ContentUnavailableView(
                        "No Quizzes Yet",
                        systemImage: "list.clipboard",
                        description: Text("Create a quiz by uploading a PDF in the Upload tab.")
                    )
                } else {
                    List {
                        ForEach(filteredQuizzes) { quiz in
                            NavigationLink(destination: QuizDetailView(quiz: quiz)) {
                                VStack(alignment: .leading) {
                                    Text(quiz.title)
                                        .font(.headline)
                                    
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text("\(quiz.questions?.count ?? 0) questions")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(quiz.createdAt, format: .dateTime.day().month().year())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: confirmDelete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Search quizzes")
            .navigationTitle("My Quizzes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Delete Quiz?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let quiz = quizToDelete {
                        deleteQuiz(quiz)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this quiz? This action cannot be undone.")
            }
        }
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        if let index = offsets.first {
            quizToDelete = filteredQuizzes[index]
            showingDeleteConfirmation = true
        }
    }
    
    private func deleteQuiz(_ quiz: Quiz) {
        withAnimation {
            modelContext.delete(quiz)
        }
    }
}

// Placeholder for QuizDetailView that will be implemented separately
struct QuizDetailView: View {
    var quiz: Quiz
    
    var body: some View {
        Text("Quiz Detail View for \(quiz.title)")
            .padding()
    }
}

#Preview {
    QuizListView()
        .modelContainer(for: Quiz.self, inMemory: true)
}
