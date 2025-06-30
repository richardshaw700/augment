import SwiftUI
import AppKit
import Combine

// MARK: - Notch View Model
class NotchViewModel: ObservableObject {
    @Published var isHovered = false
    @Published var isExpanded = true
    @Published var instruction = ""
    @Published var isTextFieldFocused = false
    @Published var showingWorkflowRecorder = false
    
    private var notchWindow: NSWindow?
    private var mouseMonitor: Any?
    private let gptService: GPTService
    private let logger: FileLogger
    private var cancellables = Set<AnyCancellable>()
    
    // Workflow recording
    @Published var workflowRecorder = WorkflowRecordingManager()
    
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
        // Don't collapse during workflow recording
        if isExpanded && instruction.isEmpty && !workflowRecorder.isRecording {
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
            let parsedText = parseGPTResponse(from: gptService.output) ?? "Thinking..."
            
            // Force UI update on main thread when new content is parsed
            DispatchQueue.main.async {
                // Trigger any necessary UI updates
                NotificationCenter.default.post(name: NSNotification.Name("GPTResponseUpdated"), object: parsedText)
            }
            
            return parsedText
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
        
        // Find all "RESPONSE FROM LLM:" sections and get the last one
        var allResponseSections: [[String]] = []
        var currentResponseLines: [String] = []
        var foundResponseMarker = false
        
        for line in lines {
            if line.contains("RESPONSE FROM LLM:") {
                // If we were already collecting a response, save it
                if foundResponseMarker && !currentResponseLines.isEmpty {
                    allResponseSections.append(currentResponseLines)
                }
                // Start collecting a new response
                foundResponseMarker = true
                currentResponseLines = []
                continue
            }
            
            // Skip separator lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "==") {
                if foundResponseMarker && !currentResponseLines.isEmpty {
                    // End of current response section, save it
                    allResponseSections.append(currentResponseLines)
                    currentResponseLines = []
                    foundResponseMarker = false
                }
                continue
            }
            
            // Collect JSON lines after finding the response marker
            if foundResponseMarker && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentResponseLines.append(line)
            }
        }
        
        // Add the last response if we were still collecting
        if foundResponseMarker && !currentResponseLines.isEmpty {
            allResponseSections.append(currentResponseLines)
        }
        
        // Use the last (most recent) response
        guard let lastResponseLines = allResponseSections.last, !lastResponseLines.isEmpty else {
            // If no new format found, try the old format as fallback
            let oldFormatLines = lines.filter { $0.contains("🤖 GPT Response:") || $0.contains("🤖 OS Response:") }
            if let lastOldLine = oldFormatLines.last {
                return parseOldFormatResponse(from: lastOldLine)
            }
            return nil
        }
        
        // Parse the JSON from the most recent response
        let jsonString = lastResponseLines.joined(separator: "")
        
        do {
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }
            
            // First try to use reasoning field (clean text)
            if let reasoning = json["reasoning"] as? String,
               !reasoning.isEmpty {
                // Log successful parsing for debugging
                FileLogger.shared.logDebug("Successfully parsed reasoning: \(String(reasoning.prefix(50)))...")
                return reasoning
            }
            
            // Fallback to raw_llm_response if reasoning is missing
            if let rawResponse = json["raw_llm_response"] as? String,
               !rawResponse.isEmpty {
                // Log fallback usage for debugging
                FileLogger.shared.logDebug("Using raw_llm_response fallback: \(String(rawResponse.prefix(50)))...")
                return rawResponse
            }
            
            return nil
        } catch {
            FileLogger.shared.logError("JSON parsing error: \(error.localizedDescription), JSON: \(jsonString)")
            return nil
        }
    }
    
    private static func parseOldFormatResponse(from line: String) -> String? {
        let jsonStart = line.range(of: "{")?.lowerBound
        let jsonEnd = line.range(of: "}", options: .backwards)?.upperBound
        
        guard let start = jsonStart,
              let end = jsonEnd,
              end <= line.endIndex else {
            return nil
        }
        
        let jsonString = String(line[start..<end])
        
        do {
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let reasoning = json["reasoning"] as? String,
                  !reasoning.isEmpty else {
                return nil
            }
            return reasoning
        } catch {
            return nil
        }
    }
}
