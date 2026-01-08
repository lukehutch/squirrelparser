package com.squirrelparser;

import java.util.Set;

/**
 * Exception thrown when CST factory validation fails.
 */
public class CSTFactoryValidationException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    private final transient Set<String> missing;
    private final transient Set<String> extra;

    /**
     * Initialize validation exception.
     *
     * @param missing Missing rule names (rules in grammar but not in factories)
     * @param extra Extra rule names (factories provided but not in grammar)
     */
    public CSTFactoryValidationException(Set<String> missing, Set<String> extra) {
        super(buildMessage(missing, extra));
        this.missing = missing;
        this.extra = extra;
    }

    private static String buildMessage(Set<String> missing, Set<String> extra) {
        StringBuilder sb = new StringBuilder("CSTFactoryValidationException:");
        if (!missing.isEmpty()) {
            sb.append(" Missing factories: ").append(missing);
        }
        if (!extra.isEmpty()) {
            sb.append(" Extra factories: ").append(extra);
        }
        return sb.toString();
    }

    /**
     * Get missing rule names.
     */
    public Set<String> getMissing() {
        return missing;
    }

    /**
     * Get extra rule names.
     */
    public Set<String> getExtra() {
        return extra;
    }
}
