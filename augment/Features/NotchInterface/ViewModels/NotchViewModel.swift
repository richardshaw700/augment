import SwiftUI
import AppKit
import Combine

// MARK: - Notch View Model
class NotchViewModel: ObservableObject {
    @Published var isHovered = false
    @Published var isExpanded = true
    @Published var instruction = ""
    @Published var isTextFieldFocused = false
    
    private var notchWindow: NSWindow?
    private var mouseMonitor: Any?
    private let gptService: GPTService
    private let logger: FileLogger
    private var cancellables = Set<AnyCancellable>()
    
    init(gptService: GPTService = GPTService(), logger: FileLogger = .shared) {
        self.gptService = gptService
        self.logger = logger
        
        setupNotchInterface()
        setupBindings()
    }
    
    // MARK: - Public Properties
    var gptManager: GPTService {
        gptService
    }
    
    var currentStreamingText: String {
        GPTResponseParser.getCurrentStreamingText(from: gptService)
    }
    
    var menuBarHeight: CGFloat {
        guard let screen = NSScreen.main else { return AppConstants.Defaults.menuBarHeight }
        let safeArea = screen.safeAreaInsets
        return safeArea.top > 0 ? safeArea.top : AppConstants.Defaults.menuBarHeight
    }
    
    // MARK: - Public Methods
    func toggleExpanded() {
        isExpanded.toggle()
        
        if isExpanded {
            animateExpansion()
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animations.focusDelay) {
                self.makeWindowKey()
                self.isTextFieldFocused = true
            }
        } else {
            animateCollapse()
            isTextFieldFocused = false
        }
    }
    
    func makeWindowKey() {
        notchWindow?.makeKey()
    }
    
    func executeInstruction() {
        guard !instruction.isEmpty && !gptService.isRunning else { return }
        gptService.executeInstruction(instruction)
    }
    
    func stopExecution() {
        gptService.stopExecution()
    }
    
    func onTextFieldTapped() {
        makeWindowKey()
        isTextFieldFocused = true
    }
    
    func onTextFieldSubmitted() {
        if !instruction.isEmpty && !gptService.isRunning {
            executeInstruction()
        }
    }
    
    func onCollapsedAreaTapped() {
        // Always make the window key first to ensure focus
        makeWindowKey()
        
        if !isExpanded {
            toggleExpanded()
        }
    }
    
    // MARK: - Private Setup Methods
    private func setupNotchInterface() {
        createNotchWindow()
        setupGlobalMouseTracking()
        setupWindowFocusObserver()
    }
    
    private func setupBindings() {
        // Monitor GPT service state changes
        gptService.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                self?.logger.log("GPT service running state changed: \(isRunning)")
                // Force UI update by triggering objectWillChange
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Monitor status changes
        gptService.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.logger.log("GPT service status changed: \(status)")
                // Force UI update
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Monitor output changes for streaming text
        gptService.$output
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Force UI update for streaming text
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func createNotchWindow() {
        let initialFrame = FrameCalculator.calculateNotchFrame(expanded: true)
        
        notchWindow = NotchWindow(
            contentRect: initialFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        guard let window = notchWindow else { return }
        
        // Configure window
        window.level = NSWindow.Level(AppConstants.Defaults.statusBarLevel)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.acceptsMouseMovedEvents = true
        
        // Set SwiftUI content with simple approach
        let contentView = NotchContentView(interface: self)
        let hostingView = NSHostingView(rootView: contentView)
        
        // Create custom tracking view and set its frame
        let trackingView = NotchTrackingView(frame: initialFrame)
        trackingView.viewModel = self
        trackingView.autoresizingMask = [.width, .height]
        
        // Add hosting view as subview with matching frame
        hostingView.frame = trackingView.bounds
        hostingView.autoresizingMask = [.width, .height]
        trackingView.addSubview(hostingView)
        
        window.contentView = trackingView
        window.makeKeyAndOrderFront(nil)
    }
    

    
    private func setupGlobalMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleGlobalMouseMove(event)
        }
    }
    
    private func setupWindowFocusObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: notchWindow,
            queue: .main
        ) { [weak self] _ in
            self?.handleWindowDidBecomeKey()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: notchWindow,
            queue: .main
        ) { [weak self] _ in
            self?.handleWindowDidResignKey()
        }
    }
    
    private func handleWindowDidBecomeKey() {
        // Auto-expand when window becomes focused and is currently collapsed
        if !isExpanded {
            toggleExpanded()
        }
    }
    
    private func handleWindowDidResignKey() {
        // Auto-collapse when window loses focus, but only if expanded and input is empty
        if isExpanded && instruction.isEmpty {
            toggleExpanded()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        guard let window = notchWindow else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        let buffer: CGFloat = 50
        
        let inNotchArea = windowFrame.contains(mouseLocation) ||
                         (mouseLocation.y > windowFrame.maxY - buffer)
        
        DispatchQueue.main.async {
            if inNotchArea != self.isHovered {
                self.setHovered(inNotchArea)
            }
        }
    }
    
    func setHovered(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        
        isHovered = hovered
        
        if hovered {
            animateHoverIn()
        } else if !isExpanded {
            animateHoverOut()
        }
    }
    

    
    // MARK: - Animation Methods
    private func animateHoverIn() {
        guard let window = notchWindow, !isExpanded else { return }
        
        let newFrame = FrameCalculator.calculateNotchFrame(expanded: false)
        let adjustedFrame = CGRect(
            x: newFrame.origin.x - AppConstants.UI.Notch.hoverWidthIncrease/2,
            y: newFrame.origin.y - AppConstants.UI.Notch.hoverHeightIncrease/2,
            width: newFrame.width + AppConstants.UI.Notch.hoverWidthIncrease,
            height: newFrame.height + AppConstants.UI.Notch.hoverHeightIncrease
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppConstants.Animations.hoverDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(adjustedFrame, display: true)
        }
    }
    
    private func animateHoverOut() {
        guard let window = notchWindow else { return }
        
        let originalFrame = FrameCalculator.calculateNotchFrame(expanded: false)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppConstants.Animations.hoverDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(originalFrame, display: true)
        }
    }
    
    private func animateExpansion() {
        guard let window = notchWindow else { return }
        
        let expandedFrame = FrameCalculator.calculateNotchFrame(expanded: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppConstants.Animations.expansionDuration
            context.timingFunction = AppConstants.Animations.expansionTimingFunction
            window.animator().setFrame(expandedFrame, display: true)
        }
    }
    
    private func animateCollapse() {
        guard let window = notchWindow else { return }
        
        let collapsedFrame = FrameCalculator.calculateNotchFrame(expanded: false)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppConstants.Animations.collapseDuration
            context.timingFunction = AppConstants.Animations.collapseTimingFunction
            window.animator().setFrame(collapsedFrame, display: true)
        }
    }
    
    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Frame Calculator
struct FrameCalculator {
    static func calculateNotchFrame(expanded: Bool) -> CGRect {
        guard let screen = NSScreen.main else { return .zero }
        
        let screenFrame = screen.frame
        let safeArea = screen.safeAreaInsets
        
        let actualNotchWidth: CGFloat = safeArea.top > 0 ? AppConstants.UI.Notch.baseWidth : 180
        let menuBarHeight: CGFloat = safeArea.top > 0 ? safeArea.top : AppConstants.Defaults.menuBarHeight
        let centerX = screenFrame.width / 2
        
        if expanded {
            let expandedWidth = actualNotchWidth + AppConstants.UI.Notch.expandedWidthPadding
            let expandedHeight = menuBarHeight + AppConstants.UI.Notch.expandedHeightExtension
            
            return CGRect(
                x: centerX - expandedWidth/2,
                y: screenFrame.height - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        } else {
            let collapsedWidth = actualNotchWidth + AppConstants.UI.Notch.collapsedWidthPadding
            let collapsedHeight = menuBarHeight + AppConstants.UI.Notch.collapsedHeightExtension
            
            return CGRect(
                x: centerX - collapsedWidth/2,
                y: screenFrame.height - collapsedHeight,
                width: collapsedWidth,
                height: collapsedHeight
            )
        }
    }
}

// MARK: - GPT Response Parser
struct GPTResponseParser {
    static func getCurrentStreamingText(from gptService: GPTService) -> String {
        guard !gptService.output.isEmpty || !gptService.isRunning else {
            return getStatusText(from: gptService)
        }
        
        if gptService.isRunning {
            return parseGPTResponse(from: gptService.output) ?? "Thinking..."
        } else {
            return getStatusText(from: gptService)
        }
    }
    
    private static func getStatusText(from gptService: GPTService) -> String {
        if gptService.isRunning {
            if gptService.status == "Starting..." {
                return "Starting..."
            } else if gptService.status == "Executing..." {
                return "Executing..."
            } else {
                return "Processing..."
            }
        } else if gptService.status == "Stopping..." {
            return "Stopping..."
        } else if !gptService.errorOutput.isEmpty {
            return "Error: \(String(gptService.errorOutput.prefix(AppConstants.Debug.errorPreviewLength)))..."
        } else if gptService.status == "Stopped by user" {
            return "Execution stopped"
        } else if gptService.status.contains("Completed") {
            return "Task completed"
        } else {
            return "Ready"
        }
    }
    
    private static func parseGPTResponse(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        let responseLines = lines.filter { $0.contains("🤖 GPT Response:") || $0.contains("🤖 OS Response:") }
        
        guard let lastResponseLine = responseLines.last else { return nil }
        
        let jsonStart: String.Index?
        let jsonEnd: String.Index?
        
        if lastResponseLine.contains("🤖 GPT Response:") {
            jsonStart = lastResponseLine.range(of: "{")?.lowerBound
            jsonEnd = lastResponseLine.range(of: "}", options: .backwards)?.upperBound
        } else if lastResponseLine.contains("🤖 OS Response:") {
            jsonStart = lastResponseLine.range(of: "{")?.lowerBound
            jsonEnd = lastResponseLine.range(of: "}", options: .backwards)?.upperBound
        } else {
            return nil
        }
        
        guard let start = jsonStart,
              let end = jsonEnd,
              end <= lastResponseLine.endIndex else {
            return nil
        }
        
        let jsonString = String(lastResponseLine[start..<end])
        
        do {
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let reasoning = json["reasoning"] as? String,
                  !reasoning.isEmpty else {
                return nil
            }
            return reasoning
        } catch {
            FileLogger.shared.logError("JSON parsing error: \(error.localizedDescription), JSON: \(jsonString)")
            return nil
        }
    }
}