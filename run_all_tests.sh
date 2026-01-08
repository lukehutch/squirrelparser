#!/bin/bash

# Function to run commands and check exit code
run_command() {
    local phase=$1
    local lang=$2
    local dir=$3
    local cmd=$4

    echo "========================================"
    echo "Running $lang $phase..."
    echo "========================================"

    cd "$dir" || { echo "Failed to enter directory $dir"; return 1; }

    eval "$cmd"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "✅ $lang $phase passed!"
    else
        echo "❌ $lang $phase failed!"
    fi

    # Return to root
    cd - > /dev/null
    return $exit_code
}

# Keep track of failures
failures=0

# Dart
if [ -d "dart" ]; then
    echo ""
    run_command "lints" "Dart" "dart" "dart analyze"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi

    echo ""
    run_command "tests" "Dart" "dart" "dart pub get && dart test"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

# Java
if [ -d "java" ]; then
    echo ""
    run_command "lints" "Java" "java" "mvn clean compile"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi

    echo ""
    run_command "tests" "Java" "java" "mvn test"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

# Python
if [ -d "python" ]; then
    echo ""
    run_command "lints" "Python" "python" "ruff check ."
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi

    echo ""
    run_command "tests" "Python" "python" "python3 -m pytest"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

# TypeScript
if [ -d "typescript" ]; then
    echo ""
    run_command "lints" "TypeScript" "typescript" "npm install && npm run lint"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi

    echo ""
    run_command "tests" "TypeScript" "typescript" "npm install && npm test"
    if [ $? -ne 0 ]; then failures=$((failures+1)); fi
fi

echo ""
echo "========================================"
if [ $failures -eq 0 ]; then
    echo "🎉 All lints and tests passed!"
    exit 0
else
    echo "💥 $failures checks failed."
    exit 1
fi
