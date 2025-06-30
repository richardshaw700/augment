#!/bin/bash

# Coordinate Detection Debug Script
# Analyzes spatial accuracy of OCR, accessibility, and grid mapping

echo "🎯 Coordinate Detection Debug Test"
echo "=================================="

# Get current timestamp for unique filenames
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

echo "$(date): Starting coordinate accuracy analysis..."

# Step 1: Run UI inspector and capture output
echo "📊 Running UI Inspector with coordinate debugging..."
swift ui_inspector.swift > "coordinate_debug_${TIMESTAMP}.log" 2>&1

# Step 2: Extract coordinate data from JSON
echo "🔍 Extracting coordinate data from latest JSON..."

# Find the most recent JSON file
LATEST_JSON=$(ls -t ./ui_map_*.json 2>/dev/null | head -1)

if [ -z "$LATEST_JSON" ]; then
    echo "❌ No JSON file found!"
    exit 1
fi

echo "📄 Analyzing: $LATEST_JSON"

# Step 3: Create coordinate analysis report
REPORT_FILE="coordinate_analysis_${TIMESTAMP}.txt"

echo "🎯 COORDINATE ACCURACY ANALYSIS" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "JSON Source: $LATEST_JSON" >> "$REPORT_FILE"
echo "=======================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Extract window bounds
echo "🪟 WINDOW BOUNDS:" >> "$REPORT_FILE"
python3 -c "
import json
import sys

try:
    with open('$LATEST_JSON', 'r') as f:
        data = json.load(f)
    
    window = data.get('window', {})
    frame = window.get('frame', {})
    print(f'Window Frame: x={frame.get(\"x\", 0)}, y={frame.get(\"y\", 0)}, width={frame.get(\"width\", 0)}, height={frame.get(\"height\", 0)}')
    print(f'Window Title: {window.get(\"title\", \"Unknown\")}')
    print('')
except Exception as e:
    print(f'Error reading window data: {e}')
" >> "$REPORT_FILE"

# Analyze OCR vs Accessibility coordinate correlation
echo "🔗 OCR vs ACCESSIBILITY CORRELATION:" >> "$REPORT_FILE"
python3 -c "
import json
import math

def distance(p1, p2):
    return math.sqrt((p1['x'] - p2['x'])**2 + (p1['y'] - p2['y'])**2)

try:
    with open('$LATEST_JSON', 'r') as f:
        data = json.load(f)
    
    elements = data.get('elements', [])
    
    # Find elements with both OCR and accessibility data
    fused_elements = []
    ocr_only = []
    accessibility_only = []
    
    for elem in elements:
        has_ocr = 'ocr' in elem and elem['ocr'] is not None
        has_acc = 'accessibility' in elem and elem['accessibility'] is not None
        
        if has_ocr and has_acc:
            fused_elements.append(elem)
        elif has_ocr:
            ocr_only.append(elem)
        elif has_acc:
            accessibility_only.append(elem)
    
    print(f'Total Elements: {len(elements)}')
    print(f'Fused (OCR + Accessibility): {len(fused_elements)}')
    print(f'OCR Only: {len(ocr_only)}')
    print(f'Accessibility Only: {len(accessibility_only)}')
    print(f'Fusion Rate: {len(fused_elements)/len(elements)*100:.1f}%')
    print('')
    
    # Analyze coordinate accuracy for key elements
    print('KEY ELEMENT COORDINATE ANALYSIS:')
    print('=' * 50)
    
    key_elements = ['Macintosh HD', 'Network', 'Applications', 'Downloads', 'Desktop', 'AirDrop']
    
    for key_name in key_elements:
        found_elements = []
        for elem in elements:
            text = elem.get('visualText', '') or ''
            if key_name.lower() in text.lower():
                found_elements.append(elem)
        
        if found_elements:
            print(f'\\n{key_name}:')
            for i, elem in enumerate(found_elements):
                pos = elem.get('position', {})
                size = elem.get('size', {})
                elem_type = elem.get('type', 'Unknown')
                confidence = elem.get('confidence', 0)
                
                # Calculate normalized coordinates (assuming 920x436 window)
                norm_x = pos.get('x', 0) / 920.0
                norm_y = pos.get('y', 0) / 436.0
                
                # Determine expected region
                if norm_x < 0.25:
                    region = 'SIDEBAR'
                elif norm_y < 0.2:
                    region = 'TOOLBAR'
                elif norm_x >= 0.25 and norm_y >= 0.2 and norm_y <= 0.85:
                    region = 'MAIN'
                else:
                    region = 'STATUS'
                
                print(f'  [{i+1}] Type: {elem_type}')
                print(f'      Position: ({pos.get(\"x\", 0):.1f}, {pos.get(\"y\", 0):.1f})')
                print(f'      Normalized: ({norm_x:.3f}, {norm_y:.3f})')
                print(f'      Size: {size.get(\"width\", 0):.1f} x {size.get(\"height\", 0):.1f}')
                print(f'      Region: {region}')
                print(f'      Confidence: {confidence:.2f}')
                
                # Check if has OCR data
                if 'ocr' in elem and elem['ocr']:
                    ocr = elem['ocr']
                    bbox = ocr.get('boundingBox', {})
                    print(f'      OCR Bounds: ({bbox.get(\"x\", 0):.3f}, {bbox.get(\"y\", 0):.3f}) {bbox.get(\"width\", 0):.3f}x{bbox.get(\"height\", 0):.3f}')
                    print(f'      OCR Confidence: {ocr.get(\"confidence\", 0):.2f}')

except Exception as e:
    print(f'Error analyzing coordinates: {e}')
    import traceback
    traceback.print_exc()
" >> "$REPORT_FILE"

# Grid mapping analysis
echo "" >> "$REPORT_FILE"
echo "🗂️ GRID MAPPING ANALYSIS:" >> "$REPORT_FILE"
python3 -c "
import json

try:
    with open('$LATEST_JSON', 'r') as f:
        data = json.load(f)
    
    elements = data.get('elements', [])
    
    # Analyze grid distribution
    grid_regions = {'toolbar': 0, 'sidebar': 0, 'main': 0, 'status': 0}
    
    for elem in elements:
        pos = elem.get('position', {})
        x, y = pos.get('x', 0), pos.get('y', 0)
        
        # Normalize coordinates (920x436 window)
        norm_x = x / 920.0
        norm_y = y / 436.0
        
        # Classify region
        if norm_y < 0.2:
            grid_regions['toolbar'] += 1
        elif norm_x < 0.25:
            grid_regions['sidebar'] += 1
        elif norm_x >= 0.25 and norm_y >= 0.2 and norm_y <= 0.85:
            grid_regions['main'] += 1
        else:
            grid_regions['status'] += 1
    
    print('Element Distribution by Region:')
    for region, count in grid_regions.items():
        percentage = count / len(elements) * 100 if elements else 0
        print(f'  {region.upper()}: {count} elements ({percentage:.1f}%)')
    
    print('')
    print('Expected vs Actual Main Content:')
    print('  Expected: Macintosh HD, Network (large, prominent)')
    print('  Actual main region elements:', grid_regions['main'])
    
    if grid_regions['main'] < 5:
        print('  ⚠️  WARNING: Very few main content elements detected!')
        print('     This suggests coordinate misalignment issues.')

except Exception as e:
    print(f'Error analyzing grid mapping: {e}')
" >> "$REPORT_FILE"

# OCR coordinate accuracy check
echo "" >> "$REPORT_FILE"
echo "📷 OCR COORDINATE ACCURACY:" >> "$REPORT_FILE"
python3 -c "
import json

try:
    with open('$LATEST_JSON', 'r') as f:
        data = json.load(f)
    
    elements = data.get('elements', [])
    
    print('OCR Elements with Suspicious Coordinates:')
    print('=' * 50)
    
    suspicious_count = 0
    
    for elem in elements:
        if 'ocr' in elem and elem['ocr']:
            text = elem.get('visualText', '')
            pos = elem.get('position', {})
            ocr = elem['ocr']
            bbox = ocr.get('boundingBox', {})
            
            # Check for main content items in wrong regions
            main_content_keywords = ['macintosh', 'network', 'drive']
            is_main_content = any(keyword in text.lower() for keyword in main_content_keywords)
            
            norm_x = pos.get('x', 0) / 920.0
            norm_y = pos.get('y', 0) / 436.0
            
            # Flag suspicious coordinates
            suspicious = False
            reasons = []
            
            if is_main_content and norm_x < 0.25:
                suspicious = True
                reasons.append('Main content in sidebar region')
            
            if bbox.get('x', 0) > 1.0 or bbox.get('y', 0) > 1.0:
                suspicious = True
                reasons.append('OCR bounds > 1.0 (invalid normalized coords)')
            
            if abs(bbox.get('x', 0) - norm_x) > 0.3:
                suspicious = True
                reasons.append('Large X coordinate discrepancy')
            
            if abs(bbox.get('y', 0) - norm_y) > 0.3:
                suspicious = True
                reasons.append('Large Y coordinate discrepancy')
            
            if suspicious:
                suspicious_count += 1
                print(f'\\n🚨 SUSPICIOUS: \"{text}\"')
                print(f'   Position: ({pos.get(\"x\", 0):.1f}, {pos.get(\"y\", 0):.1f}) -> ({norm_x:.3f}, {norm_y:.3f})')
                print(f'   OCR Bounds: ({bbox.get(\"x\", 0):.3f}, {bbox.get(\"y\", 0):.3f})')
                print(f'   Issues: {\" | \".join(reasons)}')
    
    print(f'\\nTotal Suspicious Elements: {suspicious_count}')
    
    if suspicious_count > 0:
        print('\\n💡 RECOMMENDATIONS:')
        print('   1. Check OCR coordinate normalization')
        print('   2. Verify window bounds detection')
        print('   3. Improve OCR-Accessibility spatial correlation')
        print('   4. Consider visual layout analysis')

except Exception as e:
    print(f'Error checking OCR accuracy: {e}')
" >> "$REPORT_FILE"

# Visual grid representation
echo "" >> "$REPORT_FILE"
echo "🎯 VISUAL GRID REPRESENTATION:" >> "$REPORT_FILE"
python3 -c "
import json

try:
    with open('$LATEST_JSON', 'r') as f:
        data = json.load(f)
    
    elements = data.get('elements', [])
    
    # Create a visual grid (26x30 = 780 cells)
    grid = {}
    
    for elem in elements:
        pos = elem.get('position', {})
        text = elem.get('visualText', '') or elem.get('type', 'Unknown')
        
        # Calculate grid position (A-Z, 1-30)
        x, y = pos.get('x', 0), pos.get('y', 0)
        
        # Map to grid coordinates
        col_index = min(25, max(0, int(x / 920.0 * 26)))
        row_index = min(29, max(0, int(y / 436.0 * 30)))
        
        col_char = chr(65 + col_index)  # A-Z
        row_num = row_index + 1  # 1-30
        
        grid_pos = f'{col_char}{row_num}'
        
        if grid_pos not in grid:
            grid[grid_pos] = []
        
        grid[grid_pos].append({
            'text': text[:8],  # Truncate for display
            'type': elem.get('type', 'Unknown')[:6],
            'confidence': elem.get('confidence', 0)
        })
    
    print('Grid Occupancy (showing populated cells):')
    print('Format: GridPos: [Element1, Element2, ...]')
    print('=' * 60)
    
    # Sort grid positions for better readability
    sorted_positions = sorted(grid.keys(), key=lambda x: (x[0], int(x[1:])))
    
    for pos in sorted_positions[:50]:  # Show first 50 for readability
        elements_in_cell = grid[pos]
        if elements_in_cell:
            elem_summary = []
            for elem in elements_in_cell[:3]:  # Show max 3 per cell
                elem_summary.append(f'{elem[\"text\"]} ({elem[\"confidence\"]:.2f})')
            
            extra_count = len(elements_in_cell) - 3
            if extra_count > 0:
                elem_summary.append(f'... +{extra_count} more')
            
            print(f'{pos}: {\" | \".join(elem_summary)}')
    
    if len(sorted_positions) > 50:
        print(f'... and {len(sorted_positions) - 50} more populated cells')
    
    print(f'\\nTotal Populated Cells: {len(grid)} / 780 ({len(grid)/780*100:.1f}%)')

except Exception as e:
    print(f'Error creating grid visualization: {e}')
" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "🎯 COORDINATE TEST COMPLETE" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"

# Display results
echo ""
echo "📊 COORDINATE ANALYSIS COMPLETE!"
echo "================================"
echo "📄 Full Report: $REPORT_FILE"
echo ""
echo "🔍 KEY FINDINGS SUMMARY:"
echo "========================"

# Show key findings
tail -20 "$REPORT_FILE"

echo ""
echo "💡 Next Steps:"
echo "  1. Review the full report: cat $REPORT_FILE"
echo "  2. Check suspicious coordinate elements"
echo "  3. Verify OCR normalization accuracy"
echo "  4. Consider coordinate correction algorithms"
echo ""
echo "✅ Coordinate debugging complete!" 