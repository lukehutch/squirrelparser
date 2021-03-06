// Java 1.6 grammar, ported from Parboiled
package javaparse.squirrel;

import static squirrelparser.utils.MetaGrammar.c;
import static squirrelparser.utils.MetaGrammar.cInStr;
import static squirrelparser.utils.MetaGrammar.cRange;
import static squirrelparser.utils.MetaGrammar.cSet;
import static squirrelparser.utils.MetaGrammar.collect;
import static squirrelparser.utils.MetaGrammar.first;
import static squirrelparser.utils.MetaGrammar.notFollowedBy;
import static squirrelparser.utils.MetaGrammar.oneOrMore;
import static squirrelparser.utils.MetaGrammar.optional;
import static squirrelparser.utils.MetaGrammar.predAssocRule;
import static squirrelparser.utils.MetaGrammar.ruleRef;
import static squirrelparser.utils.MetaGrammar.seq;
import static squirrelparser.utils.MetaGrammar.str;
import static squirrelparser.utils.MetaGrammar.zeroOrMore;

import java.util.Arrays;
import java.util.concurrent.atomic.AtomicInteger;

import squirrelparser.grammar.Grammar;
import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.First;
import squirrelparser.grammar.clause.nonterminal.FollowedBy;
import squirrelparser.grammar.clause.nonterminal.NotFollowedBy;
import squirrelparser.grammar.clause.nonterminal.OneOrMore;
import squirrelparser.grammar.clause.nonterminal.Optional;
import squirrelparser.grammar.clause.nonterminal.RuleRef;
import squirrelparser.grammar.clause.nonterminal.Seq;
import squirrelparser.grammar.clause.nonterminal.ZeroOrMore;
import squirrelparser.grammar.clause.terminal.Char;
import squirrelparser.grammar.clause.terminal.CharRange;
import squirrelparser.grammar.clause.terminal.CharSeq;
import squirrelparser.grammar.clause.terminal.CharSet;
import squirrelparser.utils.PrecAssocRuleRewriter;
import squirrelparser.utils.StringUtils;

public class SquirrelParboiledJavaGrammar {

    //-------------------------------------------------------------------------
    //  JLS 3.11-12  Separators, Operators
    //-------------------------------------------------------------------------

    final static Clause AT = terminal("@");
    final static Clause AND = terminal("&", cInStr("=&"));
    final static Clause ANDAND = terminal("&&");
    final static Clause ANDEQU = terminal("&=");
    final static Clause BANG = terminal("!", c('='));
    final static Clause BSR = terminal(">>>", c('='));
    final static Clause BSREQU = terminal(">>>=");
    final static Clause COLON = terminal(":");
    final static Clause COMMA = terminal(",");
    final static Clause DEC = terminal("--");
    final static Clause DIV = terminal("/", c('='));
    final static Clause DIVEQU = terminal("/=");
    final static Clause DOT = terminal(".");
    final static Clause ELLIPSIS = terminal("...");
    final static Clause EQU = terminal("=", c('='));
    final static Clause EQUAL = terminal("==");
    final static Clause GE = terminal(">=");
    final static Clause GT = terminal(">", cInStr("=>"));
    final static Clause HAT = terminal("^", c('='));
    final static Clause HATEQU = terminal("^=");
    final static Clause INC = terminal("++");
    final static Clause LBRK = terminal("[");
    final static Clause LE = terminal("<=");
    final static Clause LPAR = terminal("(");
    final static Clause LPOINT = terminal("<");
    final static Clause LT = terminal("<", cInStr("=<"));
    final static Clause LWING = terminal("{");
    final static Clause MINUS = terminal("-", cInStr("=-"));
    final static Clause MINUSEQU = terminal("-=");
    final static Clause MOD = terminal("%", c('='));
    final static Clause MODEQU = terminal("%=");
    final static Clause NOTEQUAL = terminal("!=");
    final static Clause OR = terminal("|", cInStr("=|"));
    final static Clause OREQU = terminal("|=");
    final static Clause OROR = terminal("||");
    final static Clause PLUS = terminal("+", cInStr("=+"));
    final static Clause PLUSEQU = terminal("+=");
    final static Clause QUERY = terminal("?");
    final static Clause RBRK = terminal("]");
    final static Clause RPAR = terminal(")");
    final static Clause RPOINT = terminal(">");
    final static Clause RWING = terminal("}");
    final static Clause SEMI = terminal(";");
    final static Clause SL = terminal("<<", c('='));
    final static Clause SLEQU = terminal("<<=");
    final static Clause SR = terminal(">>", cInStr("=>"));
    final static Clause SREQU = terminal(">>=");
    final static Clause STAR = terminal("*", c('='));
    final static Clause STAREQU = terminal("*=");
    final static Clause TILDA = terminal("~");

    final static Clause ANY = cRange('\0', '~');

    public final static Clause ASSERT = Keyword("assert");
    public final static Clause BREAK = Keyword("break");
    public final static Clause CASE = Keyword("case");
    public final static Clause CATCH = Keyword("catch");
    public final static Clause CLASS = Keyword("class");
    public final static Clause CONTINUE = Keyword("continue");
    public final static Clause DEFAULT = Keyword("default");
    public final static Clause DO = Keyword("do");
    public final static Clause ELSE = Keyword("else");
    public final static Clause ENUM = Keyword("enum");
    public final static Clause EXTENDS = Keyword("extends");
    public final static Clause FINALLY = Keyword("finally");
    public final static Clause FINAL = Keyword("final");
    public final static Clause FOR = Keyword("for");
    public final static Clause IF = Keyword("if");
    public final static Clause IMPLEMENTS = Keyword("implements");
    public final static Clause IMPORT = Keyword("import");
    public final static Clause INTERFACE = Keyword("interface");
    public final static Clause INSTANCEOF = Keyword("instanceof");
    public final static Clause NEW = Keyword("new");
    public final static Clause PACKAGE = Keyword("package");
    public final static Clause RETURN = Keyword("return");
    public final static Clause STATIC = Keyword("static");
    public final static Clause SUPER = Keyword("super");
    public final static Clause SWITCH = Keyword("switch");
    public final static Clause SYNCHRONIZED = Keyword("synchronized");
    public final static Clause THIS = Keyword("this");
    public final static Clause THROWS = Keyword("throws");
    public final static Clause THROW = Keyword("throw");
    public final static Clause TRY = Keyword("try");
    public final static Clause VOID = Keyword("void");
    public final static Clause WHILE = Keyword("while");

    static Clause Keyword(String keyword) {
        return terminal(keyword, ruleRef("LetterOrDigit"));
    }

    //-------------------------------------------------------------------------
    //  helper methods
    //-------------------------------------------------------------------------

    static Clause terminal(String string) {
        return seq(str(string), ruleRef("Spacing"));//.label('\'' + string + '\'')
    }

    static Clause terminal(String string, Clause mustNotFollow) {
        return seq(collect(seq(str(string), notFollowedBy(mustNotFollow))), ruleRef("Spacing"));//.label('\'' + string + '\'')
    }

    //-------------------------------------------------------------------------
    //  Compilation Unit
    //-------------------------------------------------------------------------

    public static String topLevelRuleName = "CompilationUnit";

    public static Grammar grammar = new Grammar(PrecAssocRuleRewriter.rewrite(Arrays.asList(

            predAssocRule("CompilationUnit", seq(ruleRef("Spacing"), optional(ruleRef("PackageDeclaration")),
                    zeroOrMore(ruleRef("ImportDeclaration")), zeroOrMore(ruleRef("TypeDeclaration")) //,
            //EOI
            )),

            predAssocRule("PackageDeclaration",
                    seq(zeroOrMore(ruleRef("Annotation")), seq(PACKAGE, ruleRef("QualifiedIdentifier"), SEMI))),

            predAssocRule("ImportDeclaration",
                    seq(IMPORT, optional(STATIC), ruleRef("QualifiedIdentifier"), optional(seq(DOT, STAR)), SEMI)),

            predAssocRule(
                    "TypeDeclaration", first(
                            seq(zeroOrMore(ruleRef("Modifier")),
                                    first(ruleRef("ClassDeclaration"), ruleRef("EnumDeclaration"),
                                            ruleRef("InterfaceDeclaration"), ruleRef("AnnotationTypeDeclaration"))),
                            SEMI)),

            //-------------------------------------------------------------------------
            //  Class Declaration
            //-------------------------------------------------------------------------

            predAssocRule("ClassDeclaration",
                    seq(CLASS, ruleRef("Identifier"), optional(ruleRef("TypeParameters")),
                            optional(seq(EXTENDS, ruleRef("ClassType"))),
                            optional(seq(IMPLEMENTS, ruleRef("ClassTypeList"))), ruleRef("ClassBody"))),

            predAssocRule("ClassBody", seq(LWING, zeroOrMore(ruleRef("ClassBodyDeclaration")), RWING)),

            predAssocRule("ClassBodyDeclaration",
                    first(SEMI, seq(optional(STATIC), ruleRef("Block")),
                            seq(zeroOrMore(ruleRef("Modifier")), ruleRef("MemberDecl")))),

            predAssocRule("MemberDecl",
                    first(seq(ruleRef("TypeParameters"), ruleRef("GenericMethodOrConstructorRest")),
                            seq(ruleRef("Type"), ruleRef("Identifier"), ruleRef("MethodDeclaratorRest")),
                            seq(ruleRef("Type"), ruleRef("VariableDeclarators"), SEMI),
                            seq(VOID, ruleRef("Identifier"), ruleRef("VoidMethodDeclaratorRest")),
                            seq(ruleRef("Identifier"), ruleRef("ConstructorDeclaratorRest")),
                            ruleRef("InterfaceDeclaration"), ruleRef("ClassDeclaration"),
                            ruleRef("EnumDeclaration"), ruleRef("AnnotationTypeDeclaration"))),

            predAssocRule("GenericMethodOrConstructorRest",
                    first(seq(first(ruleRef("Type"), VOID), ruleRef("Identifier"), ruleRef("MethodDeclaratorRest")),
                            seq(ruleRef("Identifier"), ruleRef("ConstructorDeclaratorRest")))),

            predAssocRule("MethodDeclaratorRest",
                    seq(ruleRef("FormalParameters"), zeroOrMore(ruleRef("Dim")),
                            optional(seq(THROWS, ruleRef("ClassTypeList"))), first(ruleRef("MethodBody"), SEMI))),

            predAssocRule("VoidMethodDeclaratorRest",
                    seq(ruleRef("FormalParameters"), optional(seq(THROWS, ruleRef("ClassTypeList"))),
                            first(ruleRef("MethodBody"), SEMI))),

            predAssocRule("ConstructorDeclaratorRest",
                    seq(ruleRef("FormalParameters"), optional(seq(THROWS, ruleRef("ClassTypeList"))),
                            ruleRef("MethodBody"))),

            predAssocRule("MethodBody", ruleRef("Block")),

            //-------------------------------------------------------------------------
            //  Interface Declaration
            //-------------------------------------------------------------------------

            predAssocRule("InterfaceDeclaration",
                    seq(INTERFACE, ruleRef("Identifier"), optional(ruleRef("TypeParameters")),
                            optional(seq(EXTENDS, ruleRef("ClassTypeList"))), ruleRef("InterfaceBody"))),

            predAssocRule("InterfaceBody", seq(LWING, zeroOrMore(ruleRef("InterfaceBodyDeclaration")), RWING)),

            predAssocRule("InterfaceBodyDeclaration",
                    first(seq(zeroOrMore(ruleRef("Modifier")), ruleRef("InterfaceMemberDecl")), SEMI)),

            predAssocRule("InterfaceMemberDecl",
                    first(ruleRef("InterfaceMethodOrFieldDecl"), ruleRef("InterfaceGenericMethodDecl"),
                            seq(VOID, ruleRef("Identifier"), ruleRef("VoidInterfaceMethodDeclaratorsRest")),
                            ruleRef("InterfaceDeclaration"), ruleRef("AnnotationTypeDeclaration"),
                            ruleRef("ClassDeclaration"), ruleRef("EnumDeclaration"))),

            predAssocRule("InterfaceMethodOrFieldDecl",
                    seq(seq(ruleRef("Type"), ruleRef("Identifier")), ruleRef("InterfaceMethodOrFieldRest"))),

            predAssocRule("InterfaceMethodOrFieldRest",
                    first(seq(ruleRef("ConstantDeclaratorsRest"), SEMI), ruleRef("InterfaceMethodDeclaratorRest"))),

            predAssocRule("InterfaceMethodDeclaratorRest",
                    seq(ruleRef("FormalParameters"), zeroOrMore(ruleRef("Dim")),
                            optional(seq(THROWS, ruleRef("ClassTypeList"))), SEMI)),

            predAssocRule("InterfaceGenericMethodDecl",
                    seq(ruleRef("TypeParameters"), first(ruleRef("Type"), VOID), ruleRef("Identifier"),
                            ruleRef("InterfaceMethodDeclaratorRest"))),

            predAssocRule("VoidInterfaceMethodDeclaratorsRest",
                    seq(ruleRef("FormalParameters"), optional(seq(THROWS, ruleRef("ClassTypeList"))), SEMI)),

            predAssocRule("ConstantDeclaratorsRest",
                    seq(ruleRef("ConstantDeclaratorRest"), zeroOrMore(seq(COMMA, ruleRef("ConstantDeclarator"))))),

            predAssocRule("ConstantDeclarator", seq(ruleRef("Identifier"), ruleRef("ConstantDeclaratorRest"))),

            predAssocRule("ConstantDeclaratorRest",
                    seq(zeroOrMore(ruleRef("Dim")), EQU, ruleRef("VariableInitializer"))),

            //-------------------------------------------------------------------------
            //  Enum Declaration
            //-------------------------------------------------------------------------

            predAssocRule("EnumDeclaration",
                    seq(ENUM, ruleRef("Identifier"), optional(seq(IMPLEMENTS, ruleRef("ClassTypeList"))),
                            ruleRef("EnumBody"))),

            predAssocRule("EnumBody",
                    seq(LWING, optional(ruleRef("EnumConstants")), optional(COMMA),
                            optional(ruleRef("EnumBodyDeclarations")), RWING)),

            predAssocRule("EnumConstants",
                    seq(ruleRef("EnumConstant"), zeroOrMore(seq(COMMA, ruleRef("EnumConstant"))))),

            predAssocRule("EnumConstant",
                    seq(zeroOrMore(ruleRef("Annotation")), ruleRef("Identifier"), optional(ruleRef("Arguments")),
                            optional(ruleRef("ClassBody")))),

            predAssocRule("EnumBodyDeclarations", seq(SEMI, zeroOrMore(ruleRef("ClassBodyDeclaration")))),

            //-------------------------------------------------------------------------
            //  Variable Declarations
            //-------------------------------------------------------------------------

            predAssocRule("LocalVariableDeclarationStatement",
                    seq(zeroOrMore(first(FINAL, ruleRef("Annotation"))), ruleRef("Type"),
                            ruleRef("VariableDeclarators"), SEMI)),

            predAssocRule("VariableDeclarators",
                    seq(ruleRef("VariableDeclarator"), zeroOrMore(seq(COMMA, ruleRef("VariableDeclarator"))))),

            predAssocRule("VariableDeclarator",
                    seq(ruleRef("Identifier"), zeroOrMore(ruleRef("Dim")),
                            optional(seq(EQU, ruleRef("VariableInitializer"))))),

            //-------------------------------------------------------------------------
            //  Formal Parameters
            //-------------------------------------------------------------------------

            predAssocRule("FormalParameters", seq(LPAR, optional(ruleRef("FormalParameterDecls")), RPAR)),

            predAssocRule("FormalParameter",
                    seq(zeroOrMore(first(FINAL, ruleRef("Annotation"))), ruleRef("Type"),
                            ruleRef("VariableDeclaratorId"))),

            predAssocRule("FormalParameterDecls",
                    seq(zeroOrMore(first(FINAL, ruleRef("Annotation"))), ruleRef("Type"),
                            ruleRef("FormalParameterDeclsRest"))),

            predAssocRule("FormalParameterDeclsRest",
                    first(seq(ruleRef("VariableDeclaratorId"),
                            optional(seq(COMMA, ruleRef("FormalParameterDecls")))),
                            seq(ELLIPSIS, ruleRef("VariableDeclaratorId")))),

            predAssocRule("VariableDeclaratorId", seq(ruleRef("Identifier"), zeroOrMore(ruleRef("Dim")))),

            //-------------------------------------------------------------------------
            //  Statements
            //-------------------------------------------------------------------------

            predAssocRule("Block", seq(LWING, ruleRef("BlockStatements"), RWING)),

            predAssocRule("BlockStatements", zeroOrMore(ruleRef("BlockStatement"))),

            predAssocRule("BlockStatement", first(ruleRef("LocalVariableDeclarationStatement"),
                    seq(zeroOrMore(ruleRef("Modifier")),
                            first(ruleRef("ClassDeclaration"), ruleRef("EnumDeclaration"))),
                    ruleRef("Statement"))),

            predAssocRule("Statement", first(ruleRef("Block"),
                    seq(ASSERT, ruleRef("Expression"), optional(seq(COLON, ruleRef("Expression"))), SEMI),
                    seq(IF, ruleRef("ParExpression"), ruleRef("Statement"),
                            optional(seq(ELSE, ruleRef("Statement")))),
                    seq(FOR, LPAR, optional(ruleRef("ForInit")), SEMI, optional(ruleRef("Expression")), SEMI,
                            optional(ruleRef("ForUpdate")), RPAR, ruleRef("Statement")),
                    seq(FOR, LPAR, ruleRef("FormalParameter"), COLON, ruleRef("Expression"), RPAR,
                            ruleRef("Statement")),
                    seq(WHILE, ruleRef("ParExpression"), ruleRef("Statement")),
                    seq(DO, ruleRef("Statement"), WHILE, ruleRef("ParExpression"), SEMI),
                    seq(TRY, ruleRef("Block"),
                            first(seq(oneOrMore(ruleRef("Catch_")), optional(ruleRef("Finally_"))),
                                    ruleRef("Finally_"))),
                    seq(SWITCH, ruleRef("ParExpression"), LWING, ruleRef("SwitchBlockStatementGroups"), RWING),
                    seq(SYNCHRONIZED, ruleRef("ParExpression"), ruleRef("Block")),
                    seq(RETURN, optional(ruleRef("Expression")), SEMI), seq(THROW, ruleRef("Expression"), SEMI),
                    seq(BREAK, optional(ruleRef("Identifier")), SEMI),
                    seq(CONTINUE, optional(ruleRef("Identifier")), SEMI),
                    seq(seq(ruleRef("Identifier"), COLON), ruleRef("Statement")),
                    seq(ruleRef("StatementExpression"), SEMI), SEMI)),

            predAssocRule("Catch_", seq(CATCH, LPAR, ruleRef("FormalParameter"), RPAR, ruleRef("Block"))),

            predAssocRule("Finally_", seq(FINALLY, ruleRef("Block"))),

            predAssocRule("SwitchBlockStatementGroups", zeroOrMore(ruleRef("SwitchBlockStatementGroup"))),

            predAssocRule("SwitchBlockStatementGroup", seq(ruleRef("SwitchLabel"), ruleRef("BlockStatements"))),

            predAssocRule("SwitchLabel",
                    first(seq(CASE, ruleRef("ConstantExpression"), COLON),
                            seq(CASE, ruleRef("EnumConstantName"), COLON), seq(DEFAULT, COLON))),

            predAssocRule("ForInit", first(
                    seq(zeroOrMore(first(FINAL, ruleRef("Annotation"))), ruleRef("Type"),
                            ruleRef("VariableDeclarators")),
                    seq(ruleRef("StatementExpression"), zeroOrMore(seq(COMMA, ruleRef("StatementExpression")))))),

            predAssocRule("ForUpdate",
                    seq(ruleRef("StatementExpression"), zeroOrMore(seq(COMMA, ruleRef("StatementExpression"))))),

            predAssocRule("EnumConstantName", ruleRef("Identifier")),

            //-------------------------------------------------------------------------
            //  Expressions
            //-------------------------------------------------------------------------

            // The following is more generous than the definition in section 14.8,
            // which allows only specific forms of Expression.

            predAssocRule("StatementExpression", ruleRef("Expression")),

            predAssocRule("ConstantExpression", ruleRef("Expression")),

            // The following definition is part of the modification in JLS Chapter 18
            // to minimize look ahead. In JLS Chapter 15.27, Expression is defined
            // as AssignmentExpression, which is effectively defined as
            // (LeftHandSide AssignmentOperator)* ConditionalExpression.
            // The following is obtained by allowing ANY ConditionalExpression
            // as LeftHandSide, which results in accepting statements like 5 = a.

            predAssocRule("Expression",
                    seq(ruleRef("ConditionalExpression"),
                            zeroOrMore(seq(ruleRef("AssignmentOperator"), ruleRef("ConditionalExpression"))))),

            predAssocRule("AssignmentOperator",
                    first(EQU, PLUSEQU, MINUSEQU, STAREQU, DIVEQU, ANDEQU, OREQU, HATEQU, MODEQU, SLEQU, SREQU,
                            BSREQU)),

            predAssocRule("ConditionalExpression",
                    seq(ruleRef("ConditionalOrExpression"),
                            zeroOrMore(
                                    seq(QUERY, ruleRef("Expression"), COLON, ruleRef("ConditionalOrExpression"))))),

            predAssocRule("ConditionalOrExpression",
                    seq(ruleRef("ConditionalAndExpression"),
                            zeroOrMore(seq(OROR, ruleRef("ConditionalAndExpression"))))),

            predAssocRule("ConditionalAndExpression",
                    seq(ruleRef("InclusiveOrExpression"),
                            zeroOrMore(seq(ANDAND, ruleRef("InclusiveOrExpression"))))),

            predAssocRule("InclusiveOrExpression",
                    seq(ruleRef("ExclusiveOrExpression"), zeroOrMore(seq(OR, ruleRef("ExclusiveOrExpression"))))),

            predAssocRule("ExclusiveOrExpression",
                    seq(ruleRef("AndExpression"), zeroOrMore(seq(HAT, ruleRef("AndExpression"))))),

            predAssocRule("AndExpression",
                    seq(ruleRef("EqualityExpression"), zeroOrMore(seq(AND, ruleRef("EqualityExpression"))))),

            predAssocRule("EqualityExpression",
                    seq(ruleRef("RelationalExpression"),
                            zeroOrMore(seq(first(EQUAL, NOTEQUAL), ruleRef("RelationalExpression"))))),

            predAssocRule("RelationalExpression",
                    seq(ruleRef("ShiftExpression"),
                            zeroOrMore(first(seq(first(LE, GE, LT, GT), ruleRef("ShiftExpression")),
                                    seq(INSTANCEOF, ruleRef("ReferenceType")))))),

            predAssocRule("ShiftExpression",
                    seq(ruleRef("AdditiveExpression"),
                            zeroOrMore(seq(first(SL, SR, BSR), ruleRef("AdditiveExpression"))))),

            predAssocRule("AdditiveExpression",
                    seq(ruleRef("MultiplicativeExpression"),
                            zeroOrMore(seq(first(PLUS, MINUS), ruleRef("MultiplicativeExpression"))))),

            predAssocRule("MultiplicativeExpression",
                    seq(ruleRef("UnaryExpression"),
                            zeroOrMore(seq(first(STAR, DIV, MOD), ruleRef("UnaryExpression"))))),

            predAssocRule("UnaryExpression",
                    first(seq(ruleRef("PrefixOp"), ruleRef("UnaryExpression")),
                            seq(LPAR, ruleRef("Type"), RPAR, ruleRef("UnaryExpression")),
                            seq(ruleRef("Primary"), zeroOrMore(ruleRef("Selector")),
                                    zeroOrMore(ruleRef("PostFixOp"))))),

            predAssocRule("Primary", first(ruleRef("ParExpression"),
                    seq(ruleRef("NonWildcardTypeArguments"),
                            first(ruleRef("ExplicitGenericInvocationSuffix"), seq(THIS, ruleRef("Arguments")))),
                    seq(THIS, optional(ruleRef("Arguments"))), seq(SUPER, ruleRef("SuperSuffix")),
                    ruleRef("Literal"), seq(NEW, ruleRef("Creator")),
                    seq(ruleRef("QualifiedIdentifier"), optional(ruleRef("IdentifierSuffix"))),
                    seq(ruleRef("BasicType"), zeroOrMore(ruleRef("Dim")), DOT, CLASS), seq(VOID, DOT, CLASS))),

            predAssocRule("IdentifierSuffix", first(
                    seq(LBRK, first(
                            seq(RBRK, zeroOrMore(ruleRef("Dim")), DOT, CLASS), seq(ruleRef("Expression"), RBRK))),
                    ruleRef("Arguments"),
                    seq(DOT, first(CLASS, ruleRef("ExplicitGenericInvocation"), THIS,
                            seq(SUPER, ruleRef("Arguments")),
                            seq(NEW, optional(ruleRef("NonWildcardTypeArguments")), ruleRef("InnerCreator")))))),

            predAssocRule("ExplicitGenericInvocation",
                    seq(ruleRef("NonWildcardTypeArguments"), ruleRef("ExplicitGenericInvocationSuffix"))),

            predAssocRule("NonWildcardTypeArguments",
                    seq(LPOINT, ruleRef("ReferenceType"), zeroOrMore(seq(COMMA, ruleRef("ReferenceType"))),
                            RPOINT)),

            predAssocRule("ExplicitGenericInvocationSuffix",
                    first(seq(SUPER, ruleRef("SuperSuffix")), seq(ruleRef("Identifier"), ruleRef("Arguments")))),

            predAssocRule("PrefixOp", first(INC, DEC, BANG, TILDA, PLUS, MINUS)),

            predAssocRule("PostFixOp", first(INC, DEC)),

            predAssocRule("Selector",
                    first(seq(DOT, ruleRef("Identifier"), optional(ruleRef("Arguments"))),
                            seq(DOT, ruleRef("ExplicitGenericInvocation")), seq(DOT, THIS),
                            seq(DOT, SUPER, ruleRef("SuperSuffix")),
                            seq(DOT, NEW, optional(ruleRef("NonWildcardTypeArguments")), ruleRef("InnerCreator")),
                            ruleRef("DimExpr"))),

            predAssocRule("SuperSuffix",
                    first(ruleRef("Arguments"), seq(DOT, ruleRef("Identifier"), optional(ruleRef("Arguments"))))),

            //@MemoMismatches
            predAssocRule("BasicType",
                    seq(first(str("byte"), str("short"), str("char"), str("int"), str("long"), str("float"),
                            str("double"), str("boolean")), notFollowedBy(ruleRef("LetterOrDigit")),
                            ruleRef("Spacing"))),

            predAssocRule("Arguments",
                    seq(LPAR, optional(seq(ruleRef("Expression"), zeroOrMore(seq(COMMA, ruleRef("Expression"))))),
                            RPAR)),

            predAssocRule("Creator", first(
                    seq(optional(ruleRef("NonWildcardTypeArguments")), ruleRef("CreatedName"),
                            ruleRef("ClassCreatorRest")),
                    seq(optional(ruleRef("NonWildcardTypeArguments")),
                            first(ruleRef("ClassType"), ruleRef("BasicType")), ruleRef("ArrayCreatorRest")))),

            predAssocRule("CreatedName", seq(ruleRef("Identifier"), optional(ruleRef("NonWildcardTypeArguments")),
                    zeroOrMore(seq(DOT, ruleRef("Identifier"), optional(ruleRef("NonWildcardTypeArguments")))))),

            predAssocRule("InnerCreator", seq(ruleRef("Identifier"), ruleRef("ClassCreatorRest"))),

            // The following is more generous than JLS 15.10. According to that definition,
            // BasicType must be followed by at least one DimExpr or by ArrayInitializer.
            predAssocRule("ArrayCreatorRest",
                    seq(LBRK,
                            first(seq(RBRK, zeroOrMore(ruleRef("Dim")), ruleRef("ArrayInitializer")),
                                    seq(ruleRef("Expression"), RBRK, zeroOrMore(ruleRef("DimExpr")),
                                            zeroOrMore(ruleRef("Dim")))))),

            predAssocRule("ClassCreatorRest", seq(ruleRef("Arguments"), optional(ruleRef("ClassBody")))),

            predAssocRule("ArrayInitializer", seq(LWING,
                    optional(seq(ruleRef("VariableInitializer"),
                            zeroOrMore(seq(COMMA, ruleRef("VariableInitializer"))))),
                    optional(COMMA), RWING)),

            predAssocRule("VariableInitializer", first(ruleRef("ArrayInitializer"), ruleRef("Expression"))),

            predAssocRule("ParExpression", seq(LPAR, ruleRef("Expression"), RPAR)),

            predAssocRule("QualifiedIdentifier",
                    seq(ruleRef("Identifier"), zeroOrMore(seq(DOT, ruleRef("Identifier"))))),

            predAssocRule("Dim", seq(LBRK, RBRK)),

            predAssocRule("DimExpr", seq(LBRK, ruleRef("Expression"), RBRK)),

            //-------------------------------------------------------------------------
            //  Types and Modifiers
            //-------------------------------------------------------------------------

            predAssocRule("Type",
                    seq(first(ruleRef("BasicType"), ruleRef("ClassType")), zeroOrMore(ruleRef("Dim")))),

            predAssocRule("ReferenceType",
                    first(seq(ruleRef("BasicType"), oneOrMore(ruleRef("Dim"))),
                            seq(ruleRef("ClassType"), zeroOrMore(ruleRef("Dim"))))),

            predAssocRule("ClassType",
                    seq(ruleRef("Identifier"), optional(ruleRef("TypeArguments")),
                            zeroOrMore(seq(DOT, ruleRef("Identifier"), optional(ruleRef("TypeArguments")))))),

            predAssocRule("ClassTypeList", seq(ruleRef("ClassType"), zeroOrMore(seq(COMMA, ruleRef("ClassType"))))),

            predAssocRule("TypeArguments",
                    seq(LPOINT, ruleRef("TypeArgument"), zeroOrMore(seq(COMMA, ruleRef("TypeArgument"))), RPOINT)),

            predAssocRule("TypeArgument",
                    first(ruleRef("ReferenceType"),
                            seq(QUERY, optional(seq(first(EXTENDS, SUPER), ruleRef("ReferenceType")))))),

            predAssocRule("TypeParameters",
                    seq(LPOINT, ruleRef("TypeParameter"), zeroOrMore(seq(COMMA, ruleRef("TypeParameter"))),
                            RPOINT)),

            predAssocRule("TypeParameter", seq(ruleRef("Identifier"), optional(seq(EXTENDS, ruleRef("Bound"))))),

            predAssocRule("Bound", seq(ruleRef("ClassType"), zeroOrMore(seq(AND, ruleRef("ClassType"))))),

            // the following common definition of Modifier is part of the modification
            // in JLS Chapter 18 to minimize look ahead. The main body of JLS has
            // different lists of modifiers for different language elements.
            predAssocRule("Modifier", first(ruleRef("Annotation"),
                    seq(first(str("public"), str("protected"), str("private"), str("static"), str("abstract"),
                            str("final"), str("native"), str("synchronized"), str("transient"), str("volatile"),
                            str("strictfp")), notFollowedBy(ruleRef("LetterOrDigit")), ruleRef("Spacing")))),

            //-------------------------------------------------------------------------
            //  Annotations
            //-------------------------------------------------------------------------

            predAssocRule("AnnotationTypeDeclaration",
                    seq(AT, INTERFACE, ruleRef("Identifier"), ruleRef("AnnotationTypeBody"))),

            predAssocRule("AnnotationTypeBody",
                    seq(LWING, zeroOrMore(ruleRef("AnnotationTypeElementDeclaration")), RWING)),

            predAssocRule("AnnotationTypeElementDeclaration",
                    first(seq(zeroOrMore(ruleRef("Modifier")), ruleRef("AnnotationTypeElementRest")), SEMI)),

            predAssocRule("AnnotationTypeElementRest",
                    first(seq(ruleRef("Type"), ruleRef("AnnotationMethodOrConstantRest"), SEMI),
                            ruleRef("ClassDeclaration"), ruleRef("EnumDeclaration"),
                            ruleRef("InterfaceDeclaration"), ruleRef("AnnotationTypeDeclaration"))),

            predAssocRule("AnnotationMethodOrConstantRest",
                    first(ruleRef("AnnotationMethodRest"), ruleRef("AnnotationConstantRest"))),

            predAssocRule("AnnotationMethodRest",
                    seq(ruleRef("Identifier"), LPAR, RPAR, optional(ruleRef("DefaultValue")))),

            predAssocRule("AnnotationConstantRest", ruleRef("VariableDeclarators")),

            predAssocRule("DefaultValue", seq(DEFAULT, ruleRef("ElementValue"))),

            //@MemoMismatches
            predAssocRule("Annotation",
                    seq(AT, ruleRef("QualifiedIdentifier"), optional(ruleRef("AnnotationRest")))),

            predAssocRule("AnnotationRest",
                    first(ruleRef("NormalAnnotationRest"), ruleRef("SingleElementAnnotationRest"))),

            predAssocRule("NormalAnnotationRest", seq(LPAR, optional(ruleRef("ElementValuePairs")), RPAR)),

            predAssocRule("ElementValuePairs",
                    seq(ruleRef("ElementValuePair"), zeroOrMore(seq(COMMA, ruleRef("ElementValuePair"))))),

            predAssocRule("ElementValuePair", seq(ruleRef("Identifier"), EQU, ruleRef("ElementValue"))),

            predAssocRule("ElementValue",
                    first(ruleRef("ConditionalExpression"), ruleRef("Annotation"),
                            ruleRef("ElementValueArrayInitializer"))),

            predAssocRule("ElementValueArrayInitializer",
                    seq(LWING, optional(ruleRef("ElementValues")), optional(COMMA), RWING)),

            predAssocRule("ElementValues",
                    seq(ruleRef("ElementValue"), zeroOrMore(seq(COMMA, ruleRef("ElementValue"))))),

            predAssocRule("SingleElementAnnotationRest", seq(LPAR, ruleRef("ElementValue"), RPAR)),

            //-------------------------------------------------------------------------
            //  JLS 3.6-7  Spacing
            //-------------------------------------------------------------------------

            //@SuppressNode
            predAssocRule("Spacing", collect(zeroOrMore(first(

                    // whitespace
                    oneOrMore(cInStr(" \t\r\n\f")),

                    // traditional comment
                    seq(str("/*"), zeroOrMore(seq(notFollowedBy(str("*/")), ANY)), str("*/")),

                    // end of line comment
                    seq(str("//"), zeroOrMore(seq(notFollowedBy(cInStr("\r\n")), ANY)),
                            optional(first(str("\r\n"), c('\r'), c('\n') /* , EOI */))))))),

            //-------------------------------------------------------------------------
            //  JLS 3.8  Identifiers
            //-------------------------------------------------------------------------

            //@SuppressSubnodes
            //@MemoMismatches
            predAssocRule("Identifier",
                    collect(seq(notFollowedBy(ruleRef("Keyword")), ruleRef("Letter"),
                            zeroOrMore(ruleRef("LetterOrDigit")), ruleRef("Spacing")))),

            // JLS defines letters and digits as Unicode characters recognized
            // as such by special Java procedures.

            predAssocRule("Letter",
                    // switch to this "reduced" character space version for a ~10% parser performance speedup
                    first(cRange('a', 'z'), cRange('A', 'Z'), c('_'), c('$'))
            //return first(seq(c('\\'), ruleRef("UnicodeEscape")), new ruleRef("JavaLetterMatcher")),
            ),

            predAssocRule("LetterOrDigit",
                    // switch to this "reduced" character space version for a ~10% parser performance speedup
                    first(cRange('a', 'z'), cRange('A', 'Z'), cRange('0', '9'), c('_'), c('$'))
            //return first(seq('\\', ruleRef("UnicodeEscape")), new ruleRef("JavaLetterOrDigitMatcher")),
            ),

            //-------------------------------------------------------------------------
            //  JLS 3.9  Keywords
            //-------------------------------------------------------------------------

            predAssocRule("Keyword", collect(seq(
                    first(str("assert"), str("break"), str("case"), str("catch"), str("class"), str("const"),
                            str("continue"), str("default"), str("do"), str("else"), str("enum"), str("extends"),
                            str("finally"), str("final"), str("for"), str("goto"), str("if"), str("implements"),
                            str("import"), str("interface"), str("instanceof"), str("new"), str("package"),
                            str("return"), str("static"), str("super"), str("switch"), str("synchronized"),
                            str("this"), str("throws"), str("throw"), str("try"), str("void"), str("while")),
                    notFollowedBy(ruleRef("LetterOrDigit"))))),

            //-------------------------------------------------------------------------
            //  JLS 3.10  Literals
            //-------------------------------------------------------------------------

            predAssocRule("Literal",
                    seq(first(ruleRef("FloatLiteral"), ruleRef("IntegerLiteral"), ruleRef("CharLiteral"),
                            ruleRef("StringLiteral"), seq(str("true"), notFollowedBy(ruleRef("LetterOrDigit"))),
                            seq(str("false"), notFollowedBy(ruleRef("LetterOrDigit"))),
                            seq(str("null"), notFollowedBy(ruleRef("LetterOrDigit")))), ruleRef("Spacing"))),

            //@SuppressSubnodes
            predAssocRule("IntegerLiteral",
                    collect(seq(first(ruleRef("HexNumeral"), ruleRef("OctalNumeral"), ruleRef("DecimalNumeral")),
                            optional(cInStr("lL"))))),

            //@SuppressSubnodes
            predAssocRule("DecimalNumeral", first(c('0'), seq(cRange('1', '9'), zeroOrMore(ruleRef("Digit"))))),

            //@SuppressSubnodes

            //@MemoMismatches
            predAssocRule("HexNumeral", seq(c('0'), cSet('x', 'X'), oneOrMore(ruleRef("HexDigit")))),

            predAssocRule("HexDigit", first(cRange('a', 'f'), cRange('A', 'F'), cRange('0', '9'))),

            //@SuppressSubnodes
            predAssocRule("OctalNumeral", seq(c('0'), oneOrMore(cRange('0', '7')))),

            predAssocRule("FloatLiteral", collect(first(ruleRef("HexFloat"), ruleRef("DecimalFloat")))),

            //@SuppressSubnodes
            predAssocRule("DecimalFloat",
                    first(seq(oneOrMore(ruleRef("Digit")), c('.'), zeroOrMore(ruleRef("Digit")),
                            optional(ruleRef("Exponent")), optional(cInStr("fFdD"))),
                            seq(c('.'), oneOrMore(ruleRef("Digit")), optional(ruleRef("Exponent")),
                                    optional(cInStr("fFdD"))),
                            seq(oneOrMore(ruleRef("Digit")), ruleRef("Exponent"), optional(cInStr("fFdD"))),
                            seq(oneOrMore(ruleRef("Digit")), optional(ruleRef("Exponent")), cInStr("fFdD")))),

            predAssocRule("Exponent", seq(cInStr("eE"), optional(cInStr("+-")), oneOrMore(ruleRef("Digit")))),

            predAssocRule("Digit", cRange('0', '9')),

            //@SuppressSubnodes
            predAssocRule("HexFloat",
                    seq(ruleRef("HexSignificant"), ruleRef("BinaryExponent"), optional(cInStr("fFdD")))),

            predAssocRule("HexSignificant",
                    first(seq(first(str("0x"), str("0X")), zeroOrMore(ruleRef("HexDigit")), c('.'),
                            oneOrMore(ruleRef("HexDigit"))), seq(ruleRef("HexNumeral"), optional(c('.'))))),

            predAssocRule("BinaryExponent", seq(cInStr("pP"), optional(cInStr("+-")), oneOrMore(ruleRef("Digit")))),

            predAssocRule("CharLiteral",
                    collect(seq(c('\''), first(ruleRef("Escape"), seq(notFollowedBy(cInStr("'\\")), ANY)), //.ruleRef("suppressSubnodes"),
                            c('\'')))),

            predAssocRule("StringLiteral",
                    collect(seq(c('"'),
                            zeroOrMore(first(ruleRef("Escape"), seq(notFollowedBy(cInStr("\r\n\"\\")), ANY))), //.ruleRef("suppressSubnodes"),
                            c('"')))),

            predAssocRule("Escape",
                    seq(c('\\'), first(cInStr("btnfr\"\'\\"), ruleRef("OctalEscape"), ruleRef("UnicodeEscape")))),

            predAssocRule("OctalEscape",
                    first(seq(cRange('0', '3'), cRange('0', '7'), cRange('0', '7')),
                            seq(cRange('0', '7'), cRange('0', '7')), cRange('0', '7'))),

            predAssocRule("UnicodeEscape", seq(oneOrMore(c('u')), ruleRef("HexDigit"), ruleRef("HexDigit"),
                    ruleRef("HexDigit"), ruleRef("HexDigit")))

    )));

    // -------------------------------------------------------------------------------------------------------------

    // Convert grammar to Parboiled2 expressions

    private static AtomicInteger maxSeqLen = new AtomicInteger();

    private static void toParb2(Clause rule) {
        System.out.print("(");
        switch (rule.getClass().getSimpleName()) {
        case "Seq":
            var seq = (Seq) rule;
            for (int i = 0; i < seq.subClauses.length; i++) {
                var subClause = seq.subClauses[i];
                if (i > 0) {
                    System.out.print(" ~ ");
                }
                toParb2(subClause);
            }
            maxSeqLen.set(Math.max(maxSeqLen.get(), seq.subClauses.length));
            System.out.print(" ~> Node" + seq.subClauses.length);
            break;
        case "First":
            var first = (First) rule;
            for (int i = 0; i < first.subClauses.length; i++) {
                var subClause = first.subClauses[i];
                if (i > 0) {
                    System.out.print(" | ");
                }
                toParb2(subClause);
            }
            System.out.print(" ~> Node1");
            break;
        case "OneOrMore":
            System.out.print("oneOrMore");
            toParb2(((OneOrMore) rule).subClause);
            System.out.print(" ~> Node1");
            break;
        case "ZeroOrMore":
            System.out.print("zeroOrMore");
            toParb2(((ZeroOrMore) rule).subClause);
            System.out.print(" ~> Node1");
            break;
        case "Optional":
            System.out.print("optional");
            toParb2(((Optional) rule).subClause);
            System.out.print(" ~> Node1");
            break;
        case "FollowedBy":
            System.out.print("&");
            toParb2(((FollowedBy) rule).subClause);
            System.out.print(" ~> Node1");
            break;
        case "NotFollowedBy":
            System.out.print("!");
            toParb2(((NotFollowedBy) rule).subClause);
            System.out.print(" ~> Node1");
            break;
        case "CharSeq":
            var str = (CharSeq) rule;
            System.out.print("capture(\"" + StringUtils.escapeString(str.seq) + "\") ~> Leaf");
            break;
        case "Char":
            var ch = (Char) rule;
            if (ch.invert) {
                System.out.print("!(");
            }
            System.out.print("capture('" + StringUtils.escapeQuotedChar(((Char) rule).chr) + "') ~> Leaf");
            if (ch.invert) {
                System.out.print(")");
            }
            break;
        case "CharSet":
            var cs = (CharSet) rule;
            if (cs.invert) {
                System.out.print("!(");
            }
            System.out.print("capture(");
            var cardinality = cs.chars.cardinality();
            if (cardinality == 1 << 16) {
                System.out.print("ANY");
            } else /* if (cardinality <= 10) */ {
                System.out.print("anyOf(\"");
                for (int i = cs.chars.nextSetBit(0); i >= 0; i = cs.chars.nextSetBit(i + 1)) {
                    System.out.print(StringUtils.escapeQuotedStringChar((char) i));
                }
                System.out.print("\")");
                /* TODO figure out how to express char ranges in Parboiled2, for large char sets */
            }
            System.out.print(") ~> Leaf");
            if (cs.invert) {
                System.out.print(")");
            }
            break;
        case "CharRange":
            var cr = (CharRange) rule;
            if (cr.invert) {
                System.out.print("!(");
            }
            System.out.print("capture(");
            if (cr.minChar == (char) 0 && cr.maxChar == (char) 0xffff) {
                System.out.print("ANY");
            } else {
                System.out.print("anyOf(\"");
                for (int i = cr.minChar; i <= cr.maxChar; i++) {
                    System.out.print(StringUtils.escapeQuotedStringChar((char) i));
                }
                System.out.print("\")");
                /* TODO figure out how to express char ranges in Parboiled2, for large char ranges */
            }
            System.out.print(") ~> Leaf");
            if (cr.invert) {
                System.out.print(")");
            }
            break;
        case "RuleRef":
            var ruleRef = (RuleRef) rule;
            System.out.print(ruleRef.refdRuleName + " ~> Node1");
            break;
        default:
            throw new IllegalArgumentException(
                    "Unsupported clause type: " + rule.getClass().getSimpleName() + " : " + rule);
        }
        System.out.print(")");
    }

    @SuppressWarnings("unused")
    private static void convertToParboiled2() {
        System.out.println("package javaparse.parboiled2;\n\n" //
                + "import org.parboiled2._\n\n" //
                + "class Parboiled2JavaParser(val input: ParserInput) extends Parser {\n" //
                + "    import Parboiled2JavaParser._\n" + "    def TopRule = rule { "
                + grammar.rules.get(0).ruleName + " ~ EOI }");
        for (int i = 0; i < grammar.rules.size(); i++) {
            var rule = grammar.rules.get(i);
            System.out.print("    def " + rule.ruleName + " " + (i == 0 ? ": Rule1[Node] " : "") + "= rule { ");
            toParb2(rule);
            System.out.println(" }");
        }
        System.out.println("}\n\n" //
                + "object Parboiled2JavaParser {\n" //
                + "    def parse(input : String) = new Parboiled2JavaParser(input).TopRule.run()\n" //
                + "    sealed trait Node");
        for (int i = 0; i <= maxSeqLen.get(); i++) {
            System.out.print("    case class Node" + i + "(");
            for (int j = 0; j < i; j++) {
                if (j > 0) {
                    System.out.print(", ");
                }
                System.out.print("c" + j + ": Node");
            }
            System.out.println(") extends Node");
        }
        System.out.print("    case class Leaf() extends Node\n" //
                + "}");
    }

    //    public static void main(String[] args) {
    //        convertToParboiled2();
    //    }
}