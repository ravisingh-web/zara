import os
import re

def fix_imports():
    lib_dir = "lib"
    project_name = "zara"
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                with open(file_path, "r") as f:
                    lines = f.readlines()
                
                new_lines = []
                changed = False
                for line in lines:
                    # Search for relative imports (../ or ./)
                    match = re.search(r"(import|Import)\s+['\"](\.\.?/.*\.dart)['\"]", line)
                    if match:
                        rel_path = match.group(2)
                        # Calculate path relative to lib/
                        current_dir = os.path.relpath(root, lib_dir)
                        abs_path = os.path.normpath(os.path.join(current_dir, rel_path))
                        
                        # Replace with package import
                        new_import = f"import 'package:{project_name}/{abs_path.replace(os.sep, '/')}';"
                        new_lines.append(line.replace(match.group(0), new_import))
                        changed = True
                    else:
                        new_lines.append(line)
                
                if changed:
                    with open(file_path, "w") as f:
                        f.writelines(new_lines)
                    print(f"✅ Fixed: {file_path}")

if __name__ == "__main__":
    fix_imports()
