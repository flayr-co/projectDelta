//
//  TestContent.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct TestContent: View {
    // MARK: - PROPERTIES
    @State private var questions: [Question] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var userInput: String = ""
    @State private var userAnswer: String = ""
    
    var body: some View {
        ZStack {
            VStack {
                if currentQuestionIndex < questions.count {
                    VStack {
//                        Text("Question \(questions[currentQuestionIndex].id)")
//                            .fontWeight(.semibold)
//                            .font(.system(size: 30))
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .padding(.horizontal)
//                            .padding(.bottom, 55)
                        
                        Text(questions[currentQuestionIndex].questionText)
                            .fontWeight(.bold)
                            .font(.system(size: 23))
                        
                        TextField("Answer", text: $userInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Text("Your Answer: \(userInput)")
                        
                        HStack {
                            Button {
                                print("help needed")
                            } label: {
                                Text("Need help?")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                            .shadow(radius: 3)

                            
                            Button {
                                userAnswer = userInput
                                print("Your answer for this question: \(userInput)")
                                currentQuestionIndex += 1
                                userInput = ""
                            } label: {
                                Text("Next")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                            .shadow(radius: 3)
                        }
                    }
                } else {
                    Text("Quiz Completed")
                } //: VSTACK
            } //: VSTACK
        } //: ZSTACK
    }
}

#Preview {
    TestContent()
}
