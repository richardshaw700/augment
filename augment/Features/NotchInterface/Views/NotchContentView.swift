import SwiftUI
import AppKit

// MARK: - Notch Content View
struct NotchContentView: View {
    @ObservedObject var interface: NotchViewModel
    @State private var instruction = ""
    @FocusState private var isTextFieldFocused: Bool
    
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
                                // Main input area
                                HStack(spacing: 8) {
                                    TextField("What would you like me to do?", text: $instruction)
                                        .textFieldStyle(.roundedBorder)
                                        .focused($isTextFieldFocused)
                                        .onSubmit {
                                            interface.onTextFieldSubmitted()
                                        }
                                        .onTapGesture {
                                            interface.onTextFieldTapped()
                                        }
                                        .onChange(of: instruction) { newValue in
                                            interface.instruction = newValue
                                        }
                                    
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
                                        .disabled(instruction.isEmpty)
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
                                
                                // Streaming action display
                                HStack {
                                    Text(interface.currentStreamingText)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if interface.gptManager.isRunning {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
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