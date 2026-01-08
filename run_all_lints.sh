#!/bin/bash

# Function to run lints and check exit code
run_lint() {
    local lang=$1
    local dir=$2
    local cmd=$3

    echo "========================================"
    echo "Running $lang lints..."
    echo "========================================"

    cd "$dir" || { echo "Failed to enter directory $dir"; return 1; }

    eval "$cmd"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "✅ $lang lints passed!"
    else
        echo "❌ $lang lints failed!"
    fi

    # Return to root
    cd - > /dev/null
    return $exit_code
}

# Keep track of failures
failures=0

# Dart
if [ -d "dart" ]; then
    run_lint "Dart" "dart" "dart analyze"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""

# Java
if [ -d "java" ]; then
    run_lint "Java" "java" "mvn clean compile"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""

# Python
if [ -d "python" ]; then
    run_lint "Python" "python" "ruff check ."
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""

# TypeScript
if [ -d "typescript" ]; then
    run_lint "TypeScript" "typescript" "npm install && npm run lint"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""
echo "========================================"
if [ $failures -eq 0 ]; then
    echo "🎉 All lints passed!"
    exit 0
else
    echo "💥 $failures language(s) failed lints."
    exit 1
fi
