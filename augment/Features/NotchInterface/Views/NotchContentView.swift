import SwiftUI
import AppKit

// MARK: - Notch Content View
struct NotchContentView: View {
    @ObservedObject var interface: NotchViewModel
    @State private var instruction = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var recordingButtonPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if interface.isExpanded {
                    // Two-part expanded design
                    VStack(spacing: 0) {
                        // Top part - menu bar integration (seamless black)
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(.black)
                        .frame(height: interface.menuBarHeight)
                        .overlay(
                            // Collapsed content in menu bar area
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                                
                                Text("Augment")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                        
                        // Bottom part - extended interface
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: AppConstants.UI.Notch.cornerRadius,
                            bottomTrailingRadius: AppConstants.UI.Notch.cornerRadius,
                            topTrailingRadius: 0
                        )
                        .fill(.black)
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: AppConstants.UI.Notch.cornerRadius,
                                bottomTrailingRadius: AppConstants.UI.Notch.cornerRadius,
                                topTrailingRadius: 0
                            )
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                // Workflows header and buttons
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Workflows")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                    }
                                    
                                    // 6 numbered workflow buttons in a single horizontal row
                                    HStack(spacing: 6) {
                                        ForEach(1...6, id: \.self) { number in
                                            Button(action: {
                                                interface.instruction = "Execute blueprint \(number)"
                                                interface.executeInstruction()
                                            }) {
                                                Text("\(number)")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .frame(width: 24, height: 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .fill(.white.opacity(0.1))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 4)
                                                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(interface.gptManager.isRunning || interface.workflowRecorder.isRecording)
                                        }
                                        Spacer()
                                    }
                                }
                                
                                // Main input area
                                HStack(spacing: 8) {
                                    TextField(interface.workflowRecorder.isRecording ? "Recording workflow..." : "What would you like me to do?", text: $instruction)
                                        .textFieldStyle(.roundedBorder)
                                        .focused($isTextFieldFocused)
                                        .disabled(interface.workflowRecorder.isRecording)
                                        .onSubmit {
                                            interface.onTextFieldSubmitted()
                                        }
                                        .onTapGesture {
                                            interface.onTextFieldTapped()
                                        }
                                        .onChange(of: instruction) { newValue in
                                            interface.instruction = newValue
                                        }
                                    
                                    // Workflow recording button
                                    Button(action: {
                                        // Immediate visual feedback
                                        recordingButtonPressed.toggle()
                                        
                                        // Force immediate UI refresh
                                        withAnimation(.none) {
                                            if interface.workflowRecorder.isRecording {
                                                interface.workflowRecorder.stopRecording()
                                            } else {
                                                interface.workflowRecorder.startRecording(workflowName: "Workflow")
                                            }
                                        }
                                        
                                        // Reset button press state after a brief moment
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            recordingButtonPressed = false
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: interface.workflowRecorder.recordingState.icon)
                                                .foregroundColor(interface.workflowRecorder.recordingState.color)
                                                .font(.caption)
                                            Text(interface.workflowRecorder.recordingState.displayName)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(interface.workflowRecorder.recordingState.color.opacity(recordingButtonPressed ? 0.3 : 0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(interface.workflowRecorder.recordingState.color.opacity(recordingButtonPressed ? 0.6 : 0.3), lineWidth: 1)
                                                )
                                        )
                                        .scaleEffect(recordingButtonPressed ? 0.95 : 1.0)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if interface.gptManager.isRunning {
                                        Button(action: {
                                            interface.stopExecution()
                                        }) {
                                            Image(systemName: "stop.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.title2)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Button(action: {
                                            interface.executeInstruction()
                                        }) {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(instruction.isEmpty || interface.workflowRecorder.isRecording)
                                    }
                                    
                                    Button {
                                        interface.toggleExpanded()
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Streaming action display or workflow recording feedback
                                HStack {
                                    let displayText = interface.workflowRecorder.recordingState == .error || interface.workflowRecorder.isRecording ? interface.workflowRecorder.feedbackMessage : interface.currentStreamingText
                                    let isError = interface.workflowRecorder.recordingState == .error || displayText.contains("Error:")
                                    
                                    Text(displayText)
                                        .font(.system(size: 12))
                                        .foregroundColor(isError ? .red : .white)
                                        .lineLimit(isError ? 4 : 2)  // More lines for errors
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if interface.gptManager.isRunning {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else if interface.workflowRecorder.isRecording {
                                        // Show recording indicator
                                        HStack(spacing: 4) {
                                            Text("\(interface.workflowRecorder.stepsRecorded)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 8, height: 8)
                                                .scaleEffect(1.2)
                                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: interface.workflowRecorder.isRecording)
                                        }
                                    }
                                }
                                .frame(height: 30)
                            }
                            .padding(12)
                        )
                    }
                } else {
                    // Collapsed state - just menu bar integration with bottom corner radius
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: AppConstants.UI.Notch.cornerRadius,
                        bottomTrailingRadius: AppConstants.UI.Notch.cornerRadius,
                        topTrailingRadius: 0
                    )
                    .fill(.black)
                    .overlay(
                        HStack {
                            Spacer()
                            
                            if let logoImage = AppleIntelligenceLogo.nsImage {
                                Image(nsImage: logoImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .colorInvert() // Make it white on black background
                                    .padding(.trailing, 4) // Add extra trailing padding to prevent clipping
                            } else {
                                // Fallback to SF Symbol - most reliable option
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.trailing, 4) // Add extra trailing padding to prevent clipping
                            }
                        }
                        .padding(.horizontal, 12)
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            interface.onCollapsedAreaTapped()
            // Focus text field after expansion animation
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animations.focusDelay) {
                isTextFieldFocused = true
            }
        }
        .clipped()
        .onAppear {
            // Sync the local instruction state with the view model
            instruction = interface.instruction
        }
        .onChange(of: interface.isTextFieldFocused) { focused in
            isTextFieldFocused = focused
        }
    }
} 