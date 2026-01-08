package com.squirrelparser;

/**
 * Exception thrown when duplicate rule names are found in CST factories.
 */
public class DuplicateRuleNameException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    private final String ruleName;
    private final int count;

    /**
     * Initialize duplicate rule name exception.
     *
     * @param ruleName The rule name that appeared more than once
     * @param count The count of how many times it appeared
     */
    public DuplicateRuleNameException(String ruleName, int count) {
        super(String.format(
            "DuplicateRuleNameException: Rule \"%s\" appears %d times in factory list",
            ruleName, count
        ));
        this.ruleName = ruleName;
        this.count = count;
    }

    /**
     * Get the duplicate rule name.
     */
    public String getRuleName() {
        return ruleName;
    }

    /**
     * Get the count of occurrences.
     */
    public int getCount() {
        return count;
    }
}
