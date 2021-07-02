// Generated from Equation.g4 by ANTLR 4.9.2
package eqn.antlr4;

import java.util.List;

import org.antlr.v4.runtime.NoViableAltException;
import org.antlr.v4.runtime.Parser;
import org.antlr.v4.runtime.ParserRuleContext;
import org.antlr.v4.runtime.RecognitionException;
import org.antlr.v4.runtime.RuntimeMetaData;
import org.antlr.v4.runtime.Token;
import org.antlr.v4.runtime.TokenStream;
import org.antlr.v4.runtime.Vocabulary;
import org.antlr.v4.runtime.VocabularyImpl;
import org.antlr.v4.runtime.atn.ATN;
import org.antlr.v4.runtime.atn.ATNDeserializer;
import org.antlr.v4.runtime.atn.ParserATNSimulator;
import org.antlr.v4.runtime.atn.PredictionContextCache;
import org.antlr.v4.runtime.dfa.DFA;
import org.antlr.v4.runtime.tree.ParseTreeListener;
import org.antlr.v4.runtime.tree.TerminalNode;

@SuppressWarnings({ "all", "warnings", "unchecked", "unused", "cast" })
public class EquationParser extends Parser {
    static {
        RuntimeMetaData.checkVersion("4.9.2", RuntimeMetaData.VERSION);
    }

    protected static final DFA[] _decisionToDFA;
    protected static final PredictionContextCache _sharedContextCache = new PredictionContextCache();
    public static final int NUM = 1, OPEN = 2, CLOSE = 3, PLUS = 4, MINUS = 5, TIMES = 6, DIV = 7;
    public static final int RULE_eqn = 0, RULE_prec4 = 1, RULE_prec3 = 2, RULE_prec2 = 3, RULE_prec1 = 4,
            RULE_prec0 = 5;

    private static String[] makeRuleNames() {
        return new String[] { "eqn", "prec4", "prec3", "prec2", "prec1", "prec0" };
    }

    public static final String[] ruleNames = makeRuleNames();

    private static String[] makeLiteralNames() {
        return new String[] { null, null, "'('", "')'", "'+'", "'-'", "'*'", "'/'" };
    }

    private static final String[] _LITERAL_NAMES = makeLiteralNames();

    private static String[] makeSymbolicNames() {
        return new String[] { null, "NUM", "OPEN", "CLOSE", "PLUS", "MINUS", "TIMES", "DIV" };
    }

    private static final String[] _SYMBOLIC_NAMES = makeSymbolicNames();
    public static final Vocabulary VOCABULARY = new VocabularyImpl(_LITERAL_NAMES, _SYMBOLIC_NAMES);

    /**
     * @deprecated Use {@link #VOCABULARY} instead.
     */
    @Deprecated
    public static final String[] tokenNames;
    static {
        tokenNames = new String[_SYMBOLIC_NAMES.length];
        for (int i = 0; i < tokenNames.length; i++) {
            tokenNames[i] = VOCABULARY.getLiteralName(i);
            if (tokenNames[i] == null) {
                tokenNames[i] = VOCABULARY.getSymbolicName(i);
            }

            if (tokenNames[i] == null) {
                tokenNames[i] = "<INVALID>";
            }
        }
    }

    @Override
    @Deprecated
    public String[] getTokenNames() {
        return tokenNames;
    }

    @Override

    public Vocabulary getVocabulary() {
        return VOCABULARY;
    }

    @Override
    public String getGrammarFileName() {
        return "Equation.g4";
    }

    @Override
    public String[] getRuleNames() {
        return ruleNames;
    }

    @Override
    public String getSerializedATN() {
        return _serializedATN;
    }

    @Override
    public ATN getATN() {
        return _ATN;
    }

    public EquationParser(TokenStream input) {
        super(input);
        _interp = new ParserATNSimulator(this, _ATN, _decisionToDFA, _sharedContextCache);
    }

    public static class EqnContext extends ParserRuleContext {
        public Prec0Context prec0() {
            return getRuleContext(Prec0Context.class, 0);
        }

        public EqnContext(ParserRuleContext parent, int invokingState) {
            super(parent, invokingState);
        }

        @Override
        public int getRuleIndex() {
            return RULE_eqn;
        }

        @Override
        public void enterRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).enterEqn(this);
        }

        @Override
        public void exitRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).exitEqn(this);
        }
    }

    public final EqnContext eqn() throws RecognitionException {
        EqnContext _localctx = new EqnContext(_ctx, getState());
        enterRule(_localctx, 0, RULE_eqn);
        try {
            enterOuterAlt(_localctx, 1);
            {
                setState(12);
                prec0();
            }
        } catch (RecognitionException re) {
            _localctx.exception = re;
            _errHandler.reportError(this, re);
            _errHandler.recover(this, re);
        } finally {
            exitRule();
        }
        return _localctx;
    }

    public static class Prec4Context extends ParserRuleContext {
        public TerminalNode OPEN() {
            return getToken(EquationParser.OPEN, 0);
        }

        public Prec0Context prec0() {
            return getRuleContext(Prec0Context.class, 0);
        }

        public TerminalNode CLOSE() {
            return getToken(EquationParser.CLOSE, 0);
        }

        public Prec4Context(ParserRuleContext parent, int invokingState) {
            super(parent, invokingState);
        }

        @Override
        public int getRuleIndex() {
            return RULE_prec4;
        }

        @Override
        public void enterRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).enterPrec4(this);
        }

        @Override
        public void exitRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).exitPrec4(this);
        }
    }

    public final Prec4Context prec4() throws RecognitionException {
        Prec4Context _localctx = new Prec4Context(_ctx, getState());
        enterRule(_localctx, 2, RULE_prec4);
        try {
            enterOuterAlt(_localctx, 1);
            {
                setState(14);
                match(OPEN);
                setState(15);
                prec0();
                setState(16);
                match(CLOSE);
            }
        } catch (RecognitionException re) {
            _localctx.exception = re;
            _errHandler.reportError(this, re);
            _errHandler.recover(this, re);
        } finally {
            exitRule();
        }
        return _localctx;
    }

    public static class Prec3Context extends ParserRuleContext {
        public TerminalNode NUM() {
            return getToken(EquationParser.NUM, 0);
        }

        public Prec4Context prec4() {
            return getRuleContext(Prec4Context.class, 0);
        }

        public Prec3Context(ParserRuleContext parent, int invokingState) {
            super(parent, invokingState);
        }

        @Override
        public int getRuleIndex() {
            return RULE_prec3;
        }

        @Override
        public void enterRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).enterPrec3(this);
        }

        @Override
        public void exitRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).exitPrec3(this);
        }
    }

    public final Prec3Context prec3() throws RecognitionException {
        Prec3Context _localctx = new Prec3Context(_ctx, getState());
        enterRule(_localctx, 4, RULE_prec3);
        try {
            setState(20);
            _errHandler.sync(this);
            switch (_input.LA(1)) {
            case NUM:
                enterOuterAlt(_localctx, 1); {
                setState(18);
                match(NUM);
            }
                break;
            case OPEN:
                enterOuterAlt(_localctx, 2); {
                setState(19);
                prec4();
            }
                break;
            default:
                throw new NoViableAltException(this);
            }
        } catch (RecognitionException re) {
            _localctx.exception = re;
            _errHandler.reportError(this, re);
            _errHandler.recover(this, re);
        } finally {
            exitRule();
        }
        return _localctx;
    }

    public static class Prec2Context extends ParserRuleContext {
        public TerminalNode MINUS() {
            return getToken(EquationParser.MINUS, 0);
        }

        public Prec3Context prec3() {
            return getRuleContext(Prec3Context.class, 0);
        }

        public Prec2Context(ParserRuleContext parent, int invokingState) {
            super(parent, invokingState);
        }

        @Override
        public int getRuleIndex() {
            return RULE_prec2;
        }

        @Override
        public void enterRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).enterPrec2(this);
        }

        @Override
        public void exitRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).exitPrec2(this);
        }
    }

    public final Prec2Context prec2() throws RecognitionException {
        Prec2Context _localctx = new Prec2Context(_ctx, getState());
        enterRule(_localctx, 6, RULE_prec2);
        try {
            setState(25);
            _errHandler.sync(this);
            switch (_input.LA(1)) {
            case MINUS:
                enterOuterAlt(_localctx, 1); {
                {
                    setState(22);
                    match(MINUS);
                    setState(23);
                    prec3();
                }
            }
                break;
            case NUM:
            case OPEN:
                enterOuterAlt(_localctx, 2); {
                setState(24);
                prec3();
            }
                break;
            default:
                throw new NoViableAltException(this);
            }
        } catch (RecognitionException re) {
            _localctx.exception = re;
            _errHandler.reportError(this, re);
            _errHandler.recover(this, re);
        } finally {
            exitRule();
        }
        return _localctx;
    }

    public static class Prec1Context extends ParserRuleContext {
        public List<Prec2Context> prec2() {
            return getRuleContexts(Prec2Context.class);
        }

        public Prec2Context prec2(int i) {
            return getRuleContext(Prec2Context.class, i);
        }

        public TerminalNode TIMES() {
            return getToken(EquationParser.TIMES, 0);
        }

        public TerminalNode DIV() {
            return getToken(EquationParser.DIV, 0);
        }

        public Prec1Context(ParserRuleContext parent, int invokingState) {
            super(parent, invokingState);
        }

        @Override
        public int getRuleIndex() {
            return RULE_prec1;
        }

        @Override
        public void enterRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).enterPrec1(this);
        }

        @Override
        public void exitRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).exitPrec1(this);
        }
    }

    public final Prec1Context prec1() throws RecognitionException {
        Prec1Context _localctx = new Prec1Context(_ctx, getState());
        enterRule(_localctx, 8, RULE_prec1);
        int _la;
        try {
            setState(32);
            _errHandler.sync(this);
            switch (getInterpreter().adaptivePredict(_input, 2, _ctx)) {
            case 1:
                enterOuterAlt(_localctx, 1); {
                {
                    setState(27);
                    prec2();
                    setState(28);
                    _la = _input.LA(1);
                    if (!(_la == TIMES || _la == DIV)) {
                        _errHandler.recoverInline(this);
                    } else {
                        if (_input.LA(1) == Token.EOF)
                            matchedEOF = true;
                        _errHandler.reportMatch(this);
                        consume();
                    }
                    setState(29);
                    prec2();
                }
            }
                break;
            case 2:
                enterOuterAlt(_localctx, 2); {
                setState(31);
                prec2();
            }
                break;
            }
        } catch (RecognitionException re) {
            _localctx.exception = re;
            _errHandler.reportError(this, re);
            _errHandler.recover(this, re);
        } finally {
            exitRule();
        }
        return _localctx;
    }

    public static class Prec0Context extends ParserRuleContext {
        public List<Prec1Context> prec1() {
            return getRuleContexts(Prec1Context.class);
        }

        public Prec1Context prec1(int i) {
            return getRuleContext(Prec1Context.class, i);
        }

        public TerminalNode PLUS() {
            return getToken(EquationParser.PLUS, 0);
        }

        public TerminalNode MINUS() {
            return getToken(EquationParser.MINUS, 0);
        }

        public Prec0Context(ParserRuleContext parent, int invokingState) {
            super(parent, invokingState);
        }

        @Override
        public int getRuleIndex() {
            return RULE_prec0;
        }

        @Override
        public void enterRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).enterPrec0(this);
        }

        @Override
        public void exitRule(ParseTreeListener listener) {
            if (listener instanceof EquationListener)
                ((EquationListener) listener).exitPrec0(this);
        }
    }

    public final Prec0Context prec0() throws RecognitionException {
        Prec0Context _localctx = new Prec0Context(_ctx, getState());
        enterRule(_localctx, 10, RULE_prec0);
        int _la;
        try {
            setState(39);
            _errHandler.sync(this);
            switch (getInterpreter().adaptivePredict(_input, 3, _ctx)) {
            case 1:
                enterOuterAlt(_localctx, 1); {
                {
                    setState(34);
                    prec1();
                    setState(35);
                    _la = _input.LA(1);
                    if (!(_la == PLUS || _la == MINUS)) {
                        _errHandler.recoverInline(this);
                    } else {
                        if (_input.LA(1) == Token.EOF)
                            matchedEOF = true;
                        _errHandler.reportMatch(this);
                        consume();
                    }
                    setState(36);
                    prec1();
                }
            }
                break;
            case 2:
                enterOuterAlt(_localctx, 2); {
                setState(38);
                prec1();
            }
                break;
            }
        } catch (RecognitionException re) {
            _localctx.exception = re;
            _errHandler.reportError(this, re);
            _errHandler.recover(this, re);
        } finally {
            exitRule();
        }
        return _localctx;
    }

    public static final String _serializedATN = "\3\u608b\ua72a\u8133\ub9ed\u417c\u3be7\u7786\u5964\3\t,\4\2\t\2\4\3\t"
            + "\3\4\4\t\4\4\5\t\5\4\6\t\6\4\7\t\7\3\2\3\2\3\3\3\3\3\3\3\3\3\4\3\4\5\4"
            + "\27\n\4\3\5\3\5\3\5\5\5\34\n\5\3\6\3\6\3\6\3\6\3\6\5\6#\n\6\3\7\3\7\3"
            + "\7\3\7\3\7\5\7*\n\7\3\7\2\2\b\2\4\6\b\n\f\2\4\3\2\b\t\3\2\6\7\2)\2\16"
            + "\3\2\2\2\4\20\3\2\2\2\6\26\3\2\2\2\b\33\3\2\2\2\n\"\3\2\2\2\f)\3\2\2\2"
            + "\16\17\5\f\7\2\17\3\3\2\2\2\20\21\7\4\2\2\21\22\5\f\7\2\22\23\7\5\2\2"
            + "\23\5\3\2\2\2\24\27\7\3\2\2\25\27\5\4\3\2\26\24\3\2\2\2\26\25\3\2\2\2"
            + "\27\7\3\2\2\2\30\31\7\7\2\2\31\34\5\6\4\2\32\34\5\6\4\2\33\30\3\2\2\2"
            + "\33\32\3\2\2\2\34\t\3\2\2\2\35\36\5\b\5\2\36\37\t\2\2\2\37 \5\b\5\2 #"
            + "\3\2\2\2!#\5\b\5\2\"\35\3\2\2\2\"!\3\2\2\2#\13\3\2\2\2$%\5\n\6\2%&\t\3"
            + "\2\2&\'\5\n\6\2\'*\3\2\2\2(*\5\n\6\2)$\3\2\2\2)(\3\2\2\2*\r\3\2\2\2\6" + "\26\33\")";
    public static final ATN _ATN = new ATNDeserializer().deserialize(_serializedATN.toCharArray());
    static {
        _decisionToDFA = new DFA[_ATN.getNumberOfDecisions()];
        for (int i = 0; i < _ATN.getNumberOfDecisions(); i++) {
            _decisionToDFA[i] = new DFA(_ATN.getDecisionState(i), i);
        }
    }
}