#!/bin/bash

# Arrays to store results for summary
declare -a lang_names
declare -a lint_status
declare -a lint_times
declare -a test_status
declare -a test_counts
declare -a test_times

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

    local start_time=$(date +%s.%N)
    local output
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local elapsed=$(echo "$end_time - $start_time" | bc)

    echo "$output"

    if [ $exit_code -eq 0 ]; then
        echo "✅ $lang $phase passed!"
    else
        echo "❌ $lang $phase failed!"
    fi

    # Return to root
    cd - > /dev/null

    # Store results in global variables for the caller to read
    LAST_OUTPUT="$output"
    LAST_ELAPSED="$elapsed"
    LAST_EXIT_CODE=$exit_code

    return $exit_code
}

# Function to extract test count from output
extract_test_count() {
    local lang=$1
    local output=$2

    case $lang in
        "Dart")
            # Dart format: "+694: All tests passed!"
            echo "$output" | grep -oP '\+\K[0-9]+(?=:.*All tests passed)' | tail -1
            ;;
    esac
}

# Keep track of failures
failures=0
lang_idx=0

# Dart
if [ -d "dart" ]; then
    lang_names[$lang_idx]="Dart"

    echo ""
    run_command "lints" "Dart" "dart" "dart analyze"
    if [ $LAST_EXIT_CODE -eq 0 ]; then
        lint_status[$lang_idx]="✅ Pass"
    else
        lint_status[$lang_idx]="❌ Fail"
        failures=$((failures+1))
    fi
    lint_times[$lang_idx]=$(printf "%.2fs" "$LAST_ELAPSED")

    echo ""
    run_command "tests" "Dart" "dart" "dart pub get > /dev/null 2>&1 && dart test"
    if [ $LAST_EXIT_CODE -eq 0 ]; then
        test_status[$lang_idx]="✅ Pass"
    else
        test_status[$lang_idx]="❌ Fail"
        failures=$((failures+1))
    fi
    test_counts[$lang_idx]=$(extract_test_count "Dart" "$LAST_OUTPUT")
    test_times[$lang_idx]=$(printf "%.2fs" "$LAST_ELAPSED")

    lang_idx=$((lang_idx+1))
fi

# Print summary
echo ""
echo "========================================"
echo "                SUMMARY                 "
echo "========================================"
echo ""
printf "%-12s │ %-8s %7s │ %-7s %7s %8s\n" "Language" "Lints" "Time" "Tests" "Count" "Time"
printf "─────────────┼──────────────────┼─────────────────────────\n"

for i in "${!lang_names[@]}"; do
    # Emojis display as 2 chars wide, so use 1 less padding for columns with emojis
    printf "%-12s │ %-9s %7s │ %-6s %7s %8s\n" \
        "${lang_names[$i]}" \
        "${lint_status[$i]}" \
        "${lint_times[$i]}" \
        "${test_status[$i]}" \
        "${test_counts[$i]:-?}" \
        "${test_times[$i]}"
done

echo ""
if [ $failures -eq 0 ]; then
    echo "🎉 All lints and tests passed!"
    exit 0
else
    echo "💥 $failures checks failed."
    exit 1
fi
