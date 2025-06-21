# Augment - Claude Computer Use macOS App
# Usage: make augment

PROJECT_NAME = augment
SCHEME = augment
CONFIGURATION = Debug
PROJECT_DIR = /Users/richardshaw/augment
UI_INSPECTOR_DIR = $(PROJECT_DIR)/src/ui_inspector
PYTHON_SRC_DIR = $(PROJECT_DIR)/src

.PHONY: augment build quick-build run clean install-deps dev logs help build-ui-inspector python-run python-test ui-test full-build

# Default target - build everything and run the app
augment: full-build run

# Build everything (Xcode app + UI inspector)
full-build: build-ui-inspector build

# Build the Xcode project (always rebuilds)
build:
	@echo "🔨 Building $(PROJECT_NAME) Xcode app..."
	@cd $(PROJECT_DIR) && xcodebuild \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath ./build \
		clean build

# Quick build without cleaning (faster for small changes)
quick-build:
	@echo "⚡ Quick building $(PROJECT_NAME)..."
	@cd $(PROJECT_DIR) && xcodebuild \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath ./build \
		build

# Build the Swift UI inspector
build-ui-inspector:
	@echo "🔧 Building Swift UI inspector..."
	@cd $(UI_INSPECTOR_DIR) && swiftc -O -o compiled_ui_inspector \
		main.swift AccessibilityEngine.swift OCREngine.swift WindowManager.swift \
		DataModels.swift ShapeDetectionEngine.swift BrowserInspector.swift \
		CoordinateSystem.swift FusionEngine.swift GridMapper.swift \
		CompressionEngine.swift OutputManager.swift PerformanceMonitor.swift \
		MenuBarInspector.swift FileManager.swift
	@echo "✅ UI inspector built successfully"

# Test the UI inspector standalone
ui-test: build-ui-inspector
	@echo "🧪 Testing UI inspector..."
	@cd $(PROJECT_DIR) && ./src/ui_inspector/compiled_ui_inspector

# Run the Python system
python-run: build-ui-inspector
	@echo "🐍 Running Python computer use system..."
	@cd $(PROJECT_DIR) && source venv/bin/activate && python src/main.py --task "$(TASK)"

# Test the Python system with a simple task
python-test: build-ui-inspector
	@echo "🧪 Testing Python system with simple task..."
	@cd $(PROJECT_DIR) && source venv/bin/activate && python src/main.py --task "Inspect the current UI state"

# Run the built app
run:
	@echo "🚀 Launching $(PROJECT_NAME)..."
	@open $(PROJECT_DIR)/build/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@cd $(PROJECT_DIR) && rm -rf build/
	@cd $(PROJECT_DIR) && xcodebuild \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		clean
	@cd $(UI_INSPECTOR_DIR) && rm -f compiled_ui_inspector
	@cd $(PROJECT_DIR) && rm -rf src/debug_output/*.txt src/debug_output/*.json 2>/dev/null || true
	@echo "✅ Clean complete"

# Install Python dependencies
install-deps:
	@echo "📦 Installing Python dependencies..."
	@cd $(PROJECT_DIR) && python3 -m venv venv
	@cd $(PROJECT_DIR) && source venv/bin/activate && pip install -r requirements.txt
	@echo "✅ Dependencies installed"

# Development mode - build and run with console output
dev: full-build
	@echo "🔧 Running in development mode with console output..."
	@echo "💡 Press Ctrl+C to stop the app"
	@$(PROJECT_DIR)/build/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app/Contents/MacOS/$(PROJECT_NAME)

# Build and run with live log streaming
logs: full-build
	@echo "🚀 Launching app and streaming logs..."
	@echo "💡 Press Ctrl+C to stop log streaming"
	@open $(PROJECT_DIR)/build/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app &
	@sleep 2
	@log stream --info --predicate 'process == "augment"'

# Show help
help:
	@echo "🚀 Augment - AI Computer Control System"
	@echo "Available commands:"
	@echo ""
	@echo "📱 Xcode App Commands:"
	@echo "  make augment        - Build everything and run the app (default)"
	@echo "  make build          - Full build of Xcode app with clean"
	@echo "  make quick-build    - Fast build of Xcode app without cleaning"
	@echo "  make run            - Run the previously built app"
	@echo "  make dev            - Build and run with console output"
	@echo "  make logs           - Build, run app, and stream logs"
	@echo ""
	@echo "🔧 System Components:"
	@echo "  make build-ui-inspector - Build the Swift UI inspector"
	@echo "  make ui-test           - Test UI inspector standalone"
	@echo "  make python-run        - Run Python system (requires TASK='your task')"
	@echo "  make python-test       - Test Python system with simple task"
	@echo "  make full-build        - Build both UI inspector and Xcode app"
	@echo ""
	@echo "🛠️  Maintenance:"
	@echo "  make clean          - Clean all build artifacts"
	@echo "  make install-deps   - Install Python dependencies"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "💡 Examples:"
	@echo "  make python-run TASK='Open Safari and go to apple.com'"
	@echo "  make ui-test"
	@echo "  make augment" 