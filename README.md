# 🔮 Nebula (codename: augment) - Computer-use AI agent

**Nearly zero RAM, CPU, or cost. New capability for humankind that is currently cost-prohibitive**

---

### **📋 Quick Setup**

```bash
git clone <this-repository>
cd augment
make install-deps && make augment
```

<details>
<summary>📖 Detailed Setup Guide & Troubleshooting</summary>

### **1. Prerequisites**

- macOS (required for this project)
- Xcode (latest version recommended)
- Python 3.8+ & Git

### **2. Setup & Verification**

#### **Step 1: Install Dependencies**

```bash
# This creates the Python virtual environment (venv) and installs packages
make install-deps
```

- **Expected Result**: A `venv/` directory is created in the project root.
- **If it fails**: Try running the steps manually:
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
  ```

#### **Step 2: Build the System & Run the App**

```bash
# This builds the Swift executables and the Xcode project, then launches the app
make augment
```

- **Expected Result**: The `compiled_ui_inspector` binary is created in `src/ui_inspector/` and the Augment application launches.
- **If it fails**:
  - Ensure Xcode is installed correctly.
  - Try cleaning previous build artifacts with `make clean` first.

#### **Step 3: Configure XCode code Signing**

To run the Swift app:

1.  Open the Xcode project: `open augment.xcodeproj`
2.  In the Project Navigator, select the `augment` project.
3.  Go to the **Signing & Capabilities** tab.
4.  Select your **Team** from the dropdown menu. Then select automatically manage signing after signing in to your personal apple account.

#### **Step 4: Grant Permissions**

For the app to function correctly, you must grant it permissions in System Preferences:

1.  Open **System Settings > Privacy & Security**.
2.  Go to **Accessibility** and add/enable the **Augment** app.
3.  Go to **Input Monitoring** and add/enable the **Augment** app.

### **3. Troubleshooting**

- **Path Issues**: The project now detects paths automatically. If you have issues, ensure you are running `make` commands from the project root directory. As a last resort, you can manually set the project root: `export AUGMENT_PROJECT_ROOT=$(pwd)`
- **Build Issues**: Always try `make clean` before rebuilding. Make sure your Python virtual environment is active if you are running scripts manually.

### **4. Key Information**

- **Python Environment (`venv/`)**: This directory is created locally on your machine and is not included in the git repository. You must run `make install-deps` to create it.
- **Swift Binaries (`compiled_ui_inspector`)**: This executable is built locally on your machine to ensure compatibility and is also not included in the git repository.
- **All Build Commands**: To see a full list of available commands, run `make help`.

</details>

---

### Codebase Overview

This project is a hybrid system designed for advanced AI-driven computer automation on macOS. It combines a native Swift front-end with a Python backend for intelligent task execution.

**Core Architecture:**

- **Swift UI & Application (`augment/`):** A native macOS application providing the user interface, such as the notch bar for interacting with the system. It acts as the entry point and communicates with the Python backend.

- **Python Agent & Orchestrator (`src/`):** The brain of the operation. This backend receives tasks, manages the AI agent, interacts with various LLMs, and decides on the sequence of actions to perform.

**Key Components:**

- **Dynamic UI Inspector (`src/ui_inspector/`):** This is the system's "eyes." It's a powerful, standalone Swift executable that is called by the Python backend. Instead of relying on screenshots, it uses a multi-engine approach to build a structured, semantic understanding of what's on the screen:

  - **Accessibility Engine:** Gathers data on UI elements like buttons, text fields, and their properties.
  - **OCR Engine:** Reads text that is not exposed via accessibility.
  - **Shape Detection:** Visually identifies interactive elements like icons and controls.
  - **Fusion Engine:** Intelligently combines data from all engines into a single, deduplicated UI map.

- **Action Executor (`src/actions/`):** Translates the LLM's high-level decisions (e.g., "click the send button") into low-level macOS events. It has context-aware strategies for different situations like filling forms or navigating web pages.

- **Workflow Automation (`src/workflow_automation/`):** Includes tools for recording user actions (mouse clicks, keyboard inputs) and analyzing them, laying the groundwork for creating and replaying complex automated workflows.

This architecture allows the system to be both highly performant (by using native Swift for UI inspection) and flexible (by using Python for the rapidly-evolving AI logic).
