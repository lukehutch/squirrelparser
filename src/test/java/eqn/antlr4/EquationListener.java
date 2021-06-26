// Generated from Equation.g4 by ANTLR 4.9.2
package eqn.antlr4;

import org.antlr.v4.runtime.tree.ParseTreeListener;

/**
 * This interface defines a complete listener for a parse tree produced by {@link EquationParser}.
 */
public interface EquationListener extends ParseTreeListener {
    /**
     * Enter a parse tree produced by {@link EquationParser#eqn}.
     * 
     * @param ctx the parse tree
     */
    void enterEqn(EquationParser.EqnContext ctx);

    /**
     * Exit a parse tree produced by {@link EquationParser#eqn}.
     * 
     * @param ctx the parse tree
     */
    void exitEqn(EquationParser.EqnContext ctx);

    /**
     * Enter a parse tree produced by {@link EquationParser#prec4}.
     * 
     * @param ctx the parse tree
     */
    void enterPrec4(EquationParser.Prec4Context ctx);

    /**
     * Exit a parse tree produced by {@link EquationParser#prec4}.
     * 
     * @param ctx the parse tree
     */
    void exitPrec4(EquationParser.Prec4Context ctx);

    /**
     * Enter a parse tree produced by {@link EquationParser#prec3}.
     * 
     * @param ctx the parse tree
     */
    void enterPrec3(EquationParser.Prec3Context ctx);

    /**
     * Exit a parse tree produced by {@link EquationParser#prec3}.
     * 
     * @param ctx the parse tree
     */
    void exitPrec3(EquationParser.Prec3Context ctx);

    /**
     * Enter a parse tree produced by {@link EquationParser#prec2}.
     * 
     * @param ctx the parse tree
     */
    void enterPrec2(EquationParser.Prec2Context ctx);

    /**
     * Exit a parse tree produced by {@link EquationParser#prec2}.
     * 
     * @param ctx the parse tree
     */
    void exitPrec2(EquationParser.Prec2Context ctx);

    /**
     * Enter a parse tree produced by {@link EquationParser#prec1}.
     * 
     * @param ctx the parse tree
     */
    void enterPrec1(EquationParser.Prec1Context ctx);

    /**
     * Exit a parse tree produced by {@link EquationParser#prec1}.
     * 
     * @param ctx the parse tree
     */
    void exitPrec1(EquationParser.Prec1Context ctx);

    /**
     * Enter a parse tree produced by {@link EquationParser#prec0}.
     * 
     * @param ctx the parse tree
     */
    void enterPrec0(EquationParser.Prec0Context ctx);

    /**
     * Exit a parse tree produced by {@link EquationParser#prec0}.
     * 
     * @param ctx the parse tree
     */
    void exitPrec0(EquationParser.Prec0Context ctx);
}