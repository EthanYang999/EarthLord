//
//  ContentView.swift
//  EarthLord
//
//  Created by Ethan on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")

                Text("Developed by Ethan")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.body)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
