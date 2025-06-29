# Agent Computer Use - Refactored Architecture

## 🎯 Overview

This is a completely refactored computer automation system that transforms a monolithic 1700+ line file into a clean, maintainable architecture with clear separation of concerns.

## 📁 Architecture

```
computer_use/
├── _agent_orchestrator.py      # MAIN FILE - Pure pseudocode orchestration
├── adapters/                   # LLM providers (OpenAI, Ollama, etc.)
├── actions/                    # Action execution (click, type, etc.)
├── session/                    # Logging, performance, conversation
├── ui/                         # UI formatting and state management
├── workflow/                   # Task execution, completion detection
├── prompts/                    # File-based prompt system
└── utils/                      # Helper functions (extracted from main)
```

## 🎵 The Orchestrator Pattern

The `_agent_orchestrator.py` file is designed to read like **pure pseudocode**:

### Key Principles:
- **NO helper functions** - only delegation to specialized modules
- **NO business logic** - pure coordination
- **Reads like a conductor's score** - tells each musician (module) when to play
- **Perfect for junior developers** - easy to understand workflow

### Main Workflow:
```python
async def execute_task(task):
    # 1. Setup task tracking
    setup_logging_and_tracking()
    
    # 2. Execute each iteration  
    for iteration in range(max_iterations):
        llm_response = get_llm_decision()      # Delegate to LLM adapter
        result = execute_action(llm_response)   # Delegate to action executors
        check_completion(result)                # Delegate to completion detector
        update_tracking(result)                 # Delegate to session manager
    
    # 3. Provide summary
    generate_summary()                          # Delegate to logger
```

## 🏗️ Module Responsibilities

Each module has **one clear responsibility**:

- **Adapters**: Talk to different AI models (OpenAI, Ollama, OpenRouter)
- **Actions**: Perform UI/system actions (click, type, bash, etc.)
- **Session**: Log everything and track performance
- **UI**: Understand and format screen state for LLMs
- **Workflow**: Detect task completion and manage app context
- **Prompts**: Load and format all prompt templates from files
- **Utils**: Helper functions extracted from main orchestrator

## 🎯 Benefits Achieved

1. **Readability**: Main file reads like pseudocode
2. **Maintainability**: ~100-200 lines per file vs 1700 lines
3. **Testability**: Each module can be tested independently
4. **Extensibility**: Easy to add new providers/actions/workflows
5. **Separation of Concerns**: Each module has one responsibility
6. **Prompt Management**: Non-developers can edit prompts without code
7. **LLM Agnostic**: Works with any LLM provider

## 🚀 Usage

```python
# New way (recommended)
from src.agent_engine.computer_use import AgentOrchestrator
agent = AgentOrchestrator()
await agent.execute_task("Open Safari and go to apple.com")

# Simple and direct usage
from src.agent_engine.computer_use import AgentOrchestrator
agent = AgentOrchestrator()
```

## 📝 File-Based Prompts

All prompts are now in separate files:

```
prompts/
├── system.txt              # Main system prompt
├── action_guide.txt        # Available actions
├── coordinate_guide.txt    # Coordinate system
└── dynamic/               # Dynamic prompt templates
    ├── messages.txt       # Messages app guidance
    ├── completion.txt     # Task completion
    └── efficiency.txt     # Performance tips
```

This allows non-developers to edit prompts without touching code!

## 🎭 The Orchestrator Philosophy

The orchestrator follows the **"conductor pattern"**:
- It knows WHAT needs to happen (the score)
- It delegates HOW to specialized modules (the musicians)
- It coordinates WHEN things happen (the timing)
- It never performs the actual work itself

This creates code that is:
- **Predictable**: Always follows the same pattern
- **Debuggable**: Easy to trace what's happening
- **Maintainable**: Changes are isolated to specific modules
- **Readable**: Flows like natural language