//
//  ChatView.swift
//  SwiftAgentChatExample
//
//  主聊天界面
//

import SwiftUI

/// 主聊天界面
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.messages.last?.content) { _ in
                        // 流式更新时也滚动
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                
                Divider()
                
                // 输入区域
                inputArea
            }
            .navigationTitle("🤖 AI 助手")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
            }
        }
        .task {
            await viewModel.initialize()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                #if os(iOS)
                .background(Color(.systemGray6))
                #else
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .cornerRadius(22)
                .focused($isInputFocused)
                .lineLimit(1...10)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: viewModel.isProcessing ? "stop.circle.fill" : "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(buttonBackgroundColor)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            .disabled(inputText.isEmpty && !viewModel.isProcessing)
            .buttonStyle(.plain)
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }
    
    private var buttonBackgroundColor: Color {
        if viewModel.isProcessing {
            return .red
        } else if inputText.isEmpty {
            return .gray
        } else {
            return .blue
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Section("设置") {
                    Button(action: viewModel.toggleStreamingMode) {
                        Label(
                            viewModel.isStreamingEnabled ? "关闭流式输出" : "开启流式输出",
                            systemImage: viewModel.isStreamingEnabled ? "waveform.slash" : "waveform"
                        )
                    }
                }
                
                Section("历史") {
                    Button(action: viewModel.clearHistory) {
                        Label("清空对话", systemImage: "trash")
                    }
                    
                    Button(action: exportHistory) {
                        Label("导出对话", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("状态") {
                    Label(
                        "流式输出: \(viewModel.isStreamingEnabled ? "开启" : "关闭")",
                        systemImage: "info.circle"
                    )
                    Label(
                        "消息数: \(viewModel.messages.count)",
                        systemImage: "number"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func sendMessage() {
        if viewModel.isProcessing {
            // TODO: 实现取消功能
            return
        }
        
        guard !inputText.isEmpty else { return }
        
        let message = inputText
        inputText = ""
        
        // 在某些平台上需要手动取消焦点
        #if os(iOS)
        isInputFocused = false
        #endif
        
        Task {
            await viewModel.sendMessage(message)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = viewModel.messages.last else { return }
        
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func exportHistory() {
        // TODO: 实现导出功能
        print("导出对话历史")
    }
}

// MARK: - Preview

#Preview {
    ChatView()
}

