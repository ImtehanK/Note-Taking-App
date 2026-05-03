//
//  AIViewModel.swift
//  Test Dummy
//
//  Created by Jeanpierre Vidal on 2/21/26.
//
import Foundation
import SwiftUI
import Combine

class AIViewModel: ObservableObject {
    
    @Published var userInput: String = ""
    
    @Published var searchResponse: String = ""
    @Published var summaryResponse: String = ""
    
    private let aiService = AIService()
    
    // 🔍 SEARCH
    func sendMessage() {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else {
            searchResponse = "Please enter a message."
            return
        }
        
        Task {
            await sendSearch(text: trimmedInput)
        }
    }
    
    // ✂️ SUMMARY
    func sendMessage(text: String) {
        let trimmedInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else {
            summaryResponse = "No text to summarize."
            return
        }
        
        let prompt = """
        Summarize the following note in 1-2 sentences. Only return the summary, no explanations or commentary:

        \(trimmedInput)
        """
        
        Task {
            await sendSummary(text: prompt)
        }
    }
    
    // 🔍 SEARCH FUNCTION
    @MainActor
    private func sendSearch(text: String) async {
        do {
            let response = try await aiService.sendMessage(text)
            searchResponse = response
            userInput = "" // optional clean UX
        } catch {
            searchResponse = "Error: \(error.localizedDescription)"
        }
    }
    

    @MainActor
    private func sendSummary(text: String) async {
        do {
            let response = try await aiService.sendMessage(text)
            summaryResponse = response
        } catch {
            summaryResponse = "Error: \(error.localizedDescription)"
        }
    }
}
