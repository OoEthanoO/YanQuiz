//
//  PDFUploadView.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import SwiftUI
import UniformTypeIdentifiers

struct PDFUploadView: View {
    @StateObject private var viewModel = QuizViewModel()
    @State private var isShowingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var navigateToQuiz = false
    
    @AppStorage("userData") private var userDataString: String = ""
    
    private var currentUserId: String {
        if let userData = userDataString.data(using: .utf8),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            return user.id
        }
        return ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text("Upload a PDF to Create a Quiz")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Our AI will analyze your PDF and create a comprehensive quiz with multiple types of questions.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    isShowingFilePicker = true
                }) {
                    Label("Select PDF", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                if let selectedFileURL = selectedFileURL {
                    Text("Selected: \(selectedFileURL.lastPathComponent)")
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Button(action: {
                        viewModel.uploadPDF(fileURL: selectedFileURL, userId: currentUserId)
                        navigateToQuiz = true
                    }) {
                        Label("Upload and Create Quiz", systemImage: "arrow.up.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Create Quiz")
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    selectedFileURL = files.first
                case .failure(let error):
                    print("Error selecting file: \(error)")
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Generating quiz...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .navigationDestination(isPresented: $navigateToQuiz) {
                if let quiz = viewModel.currentQuiz {
                    QuizDetailView(quiz: quiz)
                }
            }
        }
    }
}
