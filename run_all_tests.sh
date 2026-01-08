#!/bin/bash

# Function to run tests and check exit code
run_tests() {
    local lang=$1
    local dir=$2
    local cmd=$3

    echo "========================================"
    echo "Running $lang tests..."
    echo "========================================"
    
    cd "$dir" || { echo "Failed to enter directory $dir"; return 1; }
    
    eval "$cmd"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "✅ $lang tests passed!"
    else
        echo "❌ $lang tests failed!"
    fi
    
    # Return to root
    cd - > /dev/null
    return $exit_code
}

# Keep track of failures
failures=0

# Dart
if [ -d "dart" ]; then
    # Ensure dependencies are gotten if needed, but 'dart test' usually handles things well if pub get was run.
    # We can run 'dart pub get' just in case.
    run_tests "Dart" "dart" "dart pub get && dart test"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""

# Java
if [ -d "java" ]; then
    run_tests "Java" "java" "mvn test"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""

# Python
if [ -d "python" ]; then
    # Assuming pytest is installed in the environment
    run_tests "Python" "python" "python3 -m pytest"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""

# TypeScript
if [ -d "typescript" ]; then
    # We run npm install to ensure dependencies are present
    run_tests "TypeScript" "typescript" "npm install && npm test"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""
echo "========================================"
if [ $failures -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "💥 $failures language(s) failed tests."
    exit 1
fi
