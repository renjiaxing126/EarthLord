//
//  ContentView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/3.
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

                Spacer()
                    .frame(height: 30)

                Text("Developed by ss")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Spacer()
                    .frame(height: 20)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
