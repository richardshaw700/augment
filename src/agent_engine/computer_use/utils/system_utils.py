"""
System utility functions extracted from the main orchestrator
"""

from pathlib import Path


class SystemUtils:
    """System-level utility functions"""
    
    @staticmethod
    def load_available_applications() -> str:
        """Load the compressed applications list for Agent context"""
        try:
            project_root = Path(__file__).parent.parent.parent.parent.parent
            apps_file = project_root / "src" / "ui_inspector" / "system_inspector" / "available_applications_compressed.txt"
            if apps_file.exists():
                with open(apps_file, 'r') as f:
                    return f.read().strip()
            else:
                return "apps(0)|No applications catalog available"
        except Exception as e:
            return f"apps(0)|Error loading applications: {str(e)}"
    
    @staticmethod
    def parse_applications_for_display(apps_text: str) -> None:
        """Display available applications in a user-friendly format"""
        if apps_text.startswith("apps("):
            # Parse the compressed format
            parts = apps_text.split("|", 1)
            if len(parts) == 2:
                count_part = parts[0]  # e.g., "apps(29)"
                apps_part = parts[1]   # e.g., "App1(bundle1),App2(bundle2)..."
                
                app_count = count_part[5:-1]  # Extract number from "apps(29)"
                app_entries = apps_part.split(",")
                
                print(f"📱 Available Applications ({app_count} total):")
                print("=" * 50)
                
                for i, entry in enumerate(app_entries, 1):
                    if "(" in entry and entry.endswith(")"):
                        app_name = entry.split("(")[0]
                        bundle_id = entry.split("(")[1][:-1]
                        print(f"{i:2d}. {app_name} ({bundle_id})")
                    else:
                        print(f"{i:2d}. {entry}")
            else:
                print("📱 Available Applications:")
                print(apps_text)
        else:
            print("📱 Available Applications:")
            print(apps_text)
    
    @staticmethod
    def get_project_paths():
        """Get standard project paths"""
        project_root = Path(__file__).parent.parent.parent.parent.parent
        return {
            "project_root": project_root,
            "ui_inspector": project_root / "src" / "ui_inspector" / "compiled_ui_inspector"
        }