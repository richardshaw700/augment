"""
Augment Logging System - Enhanced logging with debug and verbose modes
"""

import logging
import sys
from datetime import datetime
from pathlib import Path


class AugmentLogger:
    """Enhanced logging system for Augment with debug and verbose modes"""
    
    def __init__(self, debug: bool = True, verbose: bool = False):
        self.debug_enabled = debug
        self.verbose_enabled = verbose
        
        # Setup log file path
        project_root = Path(__file__).parent.parent.parent
        self.log_file = project_root / "src" / "debug_output" / "latest_run_logs.txt"
        self.session_start = datetime.now()
        
        # Initialize log file
        self._initialize_log_file()
        
        # Setup logging
        self._setup_logging()
    
    def _initialize_log_file(self):
        """Initialize the log file with session header"""
        # Ensure debug output directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(self.log_file, 'w') as f:
            f.write("🚀 AUGMENT SYSTEM - DEBUG LOG\n")
            f.write("=" * 60 + "\n")
            f.write(f"Session Started: {self.session_start.strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Debug Mode: {'ON' if self.debug_enabled else 'OFF'}\n")
            f.write(f"Verbose Mode: {'ON' if self.verbose_enabled else 'OFF'}\n")
            f.write("=" * 60 + "\n\n")
    
    def _setup_logging(self):
        """Setup Python logging configuration"""
        logging.basicConfig(
            level=logging.DEBUG if self.verbose_enabled else logging.INFO,
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(self.log_file, mode='a'),
                logging.StreamHandler(sys.stdout) if self.debug_enabled else logging.NullHandler()
            ]
        )
        self.logger = logging.getLogger('augment')
    
    def debug(self, message: str, component: str = "MAIN"):
        """Log debug message (only if DEBUG is True)"""
        if self.debug_enabled:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            formatted_message = f"[{timestamp}] [{component}] {message}"
            print(formatted_message)
            self._write_to_file(formatted_message)
    
    def verbose(self, message: str, component: str = "VERBOSE"):
        """Log verbose message (only if VERBOSE is True)"""
        if self.verbose_enabled:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            formatted_message = f"[{timestamp}] [VERBOSE] [{component}] {message}"
            print(formatted_message)
            self._write_to_file(formatted_message)
    
    def info(self, message: str, component: str = "INFO"):
        """Log info message (always shown)"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        formatted_message = f"[{timestamp}] [{component}] {message}"
        print(formatted_message)
        self._write_to_file(formatted_message)
    
    def error(self, message: str, component: str = "ERROR"):
        """Log error message (always shown)"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        formatted_message = f"[{timestamp}] [❌ {component}] {message}"
        print(formatted_message)
        self._write_to_file(formatted_message)
    
    def success(self, message: str, component: str = "SUCCESS"):
        """Log success message (always shown)"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        formatted_message = f"[{timestamp}] [✅ {component}] {message}"
        print(formatted_message)
        self._write_to_file(formatted_message)
    
    def section(self, title: str):
        """Log section header"""
        separator = "=" * 60
        section_msg = f"\n{separator}\n🎯 {title.upper()}\n{separator}"
        print(section_msg)
        self._write_to_file(section_msg)
    
    def subsection(self, title: str):
        """Log subsection header"""
        separator = "-" * 40
        subsection_msg = f"\n{separator}\n📋 {title}\n{separator}"
        if self.debug_enabled:
            print(subsection_msg)
        self._write_to_file(subsection_msg)
    
    def _write_to_file(self, message: str):
        """Write message to log file"""
        try:
            with open(self.log_file, 'a') as f:
                f.write(message + "\n")
        except Exception as e:
            # Prevent infinite loops by not logging file write errors to avoid recursion
            pass
    
    def get_log_file_path(self) -> str:
        """Get the path to the log file"""
        return str(self.log_file) 