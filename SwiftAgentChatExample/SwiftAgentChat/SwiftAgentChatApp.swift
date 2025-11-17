//
//  SwiftAgentChatApp.swift
//  SwiftAgentChatExample
//
//  AI 聊天助手应用入口
//

import SwiftUI

@main
struct SwiftAgentChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #endif
    }
}

