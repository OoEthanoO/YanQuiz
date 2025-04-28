//
//  MainTabView.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            QuizListView()
                .tabItem {
                    Label("Quizzes", systemImage: "list.bullet")
                }
                .tag(0)
            
            PDFUploadView()
                .tabItem {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }
                .tag(1)
            
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(2)
        }
    }
}
