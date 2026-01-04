//
//  TestView.swift
//  EarthLord
//
//  Created by yanshuang ren on 2026/1/4.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            // 淡蓝色背景
            Color(red: 0.7, green: 0.85, blue: 1.0)
                .ignoresSafeArea()

            VStack {
                Text("这里是分支宇宙的测试页")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
            }
        }
    }
}

#Preview {
    TestView()
}
