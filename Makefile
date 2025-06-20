# Augment - Claude Computer Use macOS App
# Usage: make augment

PROJECT_NAME = augment
SCHEME = augment
CONFIGURATION = Debug
PROJECT_DIR = /Users/richardshaw/augment

.PHONY: augment build quick-build run clean install-deps dev logs help

# Default target - build and run the app
augment: build run

# Build the Xcode project (always rebuilds)
build:
	@echo "🔨 Building $(PROJECT_NAME)..."
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

# Install Python dependencies for Claude Computer Use
install-deps:
	@echo "📦 Installing Python dependencies..."
	@cd $(PROJECT_DIR)/claude-computer-use-macos && \
		python3 -m venv venv && \
		source venv/bin/activate && \
		pip install -r requirements.txt

# Development mode - build and run with console output
dev: build
	@echo "🔧 Running in development mode with console output..."
	@echo "💡 Press Ctrl+C to stop the app"
	@$(PROJECT_DIR)/build/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app/Contents/MacOS/$(PROJECT_NAME)

# Build and run with live log streaming
logs: build
	@echo "🚀 Launching app and streaming logs..."
	@echo "💡 Press Ctrl+C to stop log streaming"
	@open $(PROJECT_DIR)/build/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app &
	@sleep 2
	@log stream --info --predicate 'process == "augment"'

# Show help
help:
	@echo "Available commands:"
	@echo "  make augment     - Build and run the app (default)"
	@echo "  make build       - Full build with clean (always rebuilds)"
	@echo "  make quick-build - Fast build without cleaning"
	@echo "  make run         - Run the previously built app"
	@echo "  make dev         - Build and run with console output in terminal"
	@echo "  make logs        - Build, run app, and stream logs"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make install-deps - Install Python dependencies"
	@echo "  make help        - Show this help message" 