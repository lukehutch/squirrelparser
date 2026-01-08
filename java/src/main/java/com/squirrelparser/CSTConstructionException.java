package com.squirrelparser;

/**
 * Exception thrown when CST construction fails.
 */
public class CSTConstructionException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    /**
     * Initialize construction exception.
     *
     * @param message Error message
     */
    public CSTConstructionException(String message) {
        super("CSTConstructionException: " + message);
    }
}
