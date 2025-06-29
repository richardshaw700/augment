"""
Performance tracking and metrics
"""

import time
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List


class PerformanceTracker:
    """Tracks and logs performance metrics for operations"""
    
    def __init__(self):
        self.operations = []
        self.session_start = time.time()
        project_root = Path(__file__).parent.parent.parent.parent.parent
        self.log_file = project_root / "src" / "debug_output" / "performance_debug.txt"
        
        # Ensure debug output directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
    
    def start_operation(self, operation_name: str) -> float:
        """Start timing an operation and return the start time"""
        start_time = time.time()
        return start_time
    
    def end_operation(self, operation_name: str, start_time: float, details: str = "", ui_breakdown: Dict = {}):
        """End timing an operation and log the result"""
        end_time = time.time()
        elapsed = end_time - start_time
        
        self.operations.append({
            "operation": operation_name,
            "elapsed": elapsed,
            "details": details,
            "timestamp": datetime.now().strftime("%H:%M:%S.%f")[:-3],
            "ui_breakdown": ui_breakdown
        })
        
        # Write updated performance log
        self._write_performance_log()
    
    def get_total_time(self) -> float:
        """Get total elapsed time since session start"""
        return time.time() - self.session_start
    
    def _write_performance_log(self):
        """Write performance data to debug file"""
        if not self.operations:
            return
            
        total_time = self.get_total_time()
        
        # Group operations by type for summary
        operation_groups = {}
        for op in self.operations:
            op_type = op["operation"]
            if op_type not in operation_groups:
                operation_groups[op_type] = []
            operation_groups[op_type].append(op)
        
        with open(self.log_file, "w") as f:
            f.write("🚀 PERFORMANCE ANALYSIS\n")
            f.write("=" * 50 + "\n")
            f.write(f"📊 Total Session Time: {total_time:.3f}s\n")
            f.write(f"🔄 Total Operations: {len(self.operations)}\n\n")
            
            # Summary by operation type
            f.write("📈 OPERATION SUMMARY:\n")
            f.write("-" * 30 + "\n")
            for op_type, ops in operation_groups.items():
                avg_time = sum(op["elapsed"] for op in ops) / len(ops)
                total_type_time = sum(op["elapsed"] for op in ops)
                f.write(f"   {op_type}: {avg_time:.3f}s avg ({len(ops)} calls, {total_type_time:.3f}s total)\n")
            
            f.write("\n🔍 DETAILED BREAKDOWN:\n")
            f.write("-" * 30 + "\n")
            
            for i, op in enumerate(self.operations, 1):
                f.write(f"   {i}. [{op['timestamp']}] {op['operation']}: {op['elapsed']:.3f}s - {op['details']}\n")
                
                # Add UI inspection breakdown if available
                if op.get('ui_breakdown') and op['operation'] == 'ui_inspect action':
                    f.write("       UI INSPECTION BREAKDOWN:\n")
                    f.write("    " + "=" * 46 + "\n")
                    
                    # Sort breakdown by time (descending)
                    breakdown_items = sorted(
                        op['ui_breakdown'].items(),
                        key=lambda x: x[1].get('time', 0) if isinstance(x[1], dict) else 0,
                        reverse=True
                    )
                    
                    for name, data in breakdown_items:
                        if isinstance(data, dict) and 'time' in data:
                            time_val = data['time']
                            percent_val = data.get('percentage', 0)
                            
                            # Format parallel detection sub-items with indentation
                            if name.startswith('  '):
                                f.write(f"        ├─ {name.strip()}: {time_val:.3f}s ({percent_val:.1f}%)\n")
                            else:
                                f.write(f"      • {name}: {time_val:.3f}s ({percent_val:.1f}%)\n")
                    
                    # Add total time if available
                    if 'TOTAL TIME' in op['ui_breakdown']:
                        total_ui_time = op['ui_breakdown']['TOTAL TIME']['time']
                        f.write("    " + "-" * 46 + "\n")
                        f.write(f"      ⚡ Total UI Inspection: {total_ui_time:.3f}s\n")
                    
                    f.write("\n")
            
            f.write("\n" + "=" * 50 + "\n")
            f.write(f"🎯 Session completed at {datetime.now().strftime('%H:%M:%S')}\n")