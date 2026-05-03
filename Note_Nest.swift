//
//  AIAppTest.swift
//  Test DummyTests
//
//  Created by Jeanpierre Vidal on 2/12/26.
//
import Foundation

class AIService {
    
    private let apiKey = "____"
    
    func sendMessage(_ message: String) async throws -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return "Please enter a message." }
        
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-5-mini",
            "input": [
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": trimmedMessage]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Status code:", httpResponse.statusCode)
        }
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Raw response:", rawResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]] else {
            return "No response"
        }
        var combinedText = ""
        for messageItem in output {
            if let contentArray = messageItem["content"] as? [[String: Any]] {
                for item in contentArray {
                    if let text = item["text"] as? String {
                        combinedText += text + "\n"
                    }
                }
            }
        }
        
        return combinedText.isEmpty ? "No response" : combinedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


