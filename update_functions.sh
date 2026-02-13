#!/bin/bash

# Find all .m files and update function/classdef names to match filenames
find SampleFiles -name "*.m" -type f | while read file; do
    # Get the filename without path
    filename=$(basename "$file")
    # Remove .m extension to get the desired function name
    funcname="${filename%.m}"
    
    # Check if it's a function or class file
    if grep -q "^function " "$file"; then
        # It's a function file - show what needs to change
        echo "FILE: $file"
        head -n 1 "$file" | grep "^function " || true
        echo "SHOULD BE: function ... = $funcname(...)"
        echo "---"
    elif grep -q "^classdef " "$file"; then
        # It's a class file
        echo "FILE: $file"
        head -n 1 "$file" | grep "^classdef " || true
        echo "SHOULD BE: classdef $funcname"
        echo "---"
    fi
done
