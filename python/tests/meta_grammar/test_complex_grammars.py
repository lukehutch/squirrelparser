"""MetaGrammar - Complex Grammars Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarComplexGrammars:
    """MetaGrammar - Complex Grammars"""

    def test_arithmetic_expression_grammar(self) -> None:
        """arithmetic expression grammar"""
        grammar = '''
            Expr <- Term ("+" Term / "-" Term)*;
            Term <- Factor ("*" Factor / "/" Factor)*;
            Factor <- Number / "(" Expr ")";
            Number <- [0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='42')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 2

        parser = Parser(rules=rules, input_str='1+2')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 3

        parser = Parser(rules=rules, input_str='1+2*3')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 5

        parser = Parser(rules=rules, input_str='(1+2)*3')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 7

    def test_identifier_and_keyword_grammar(self) -> None:
        """identifier and keyword grammar"""
        grammar = '''
            Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
            Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='foo')
        result, _ = parser.parse('Ident')
        assert result is not None

        # Use match_rule for negative test to avoid recovery
        parser = Parser(rules=rules, input_str='if')
        match_result = parser.match_rule('Ident', 0)
        assert match_result.is_mismatch  # 'if' is a keyword

        parser = Parser(rules=rules, input_str='iffy')
        result, _ = parser.parse('Ident')
        assert result is not None  # 'iffy' is not a keyword

    def test_json_grammar(self) -> None:
        """JSON grammar"""
        grammar = r'''
            Value <- String / Number / Object / Array / "true" / "false" / "null";
            Object <- "{" _ (Pair (_ "," _ Pair)*)? _ "}";
            Pair <- String _ ":" _ Value;
            Array <- "[" _ (Value (_ "," _ Value)*)? _ "]";
            String <- "\"" [^"]* "\"";
            Number <- [0-9]+;
            _ <- [ \t\n\r]*;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='{}')
        result, _ = parser.parse('Object')
        assert result is not None

        parser = Parser(rules=rules, input_str='[]')
        result, _ = parser.parse('Array')
        assert result is not None

        parser = Parser(rules=rules, input_str='"hello"')
        result, _ = parser.parse('String')
        assert result is not None

        parser = Parser(rules=rules, input_str='123')
        result, _ = parser.parse('Number')
        assert result is not None

    def test_whitespace_handling(self) -> None:
        """whitespace handling"""
        grammar = r'''
            Main <- _ "hello" _ "world" _;
            _ <- [ \t\n\r]*;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='helloworld')
        result, _ = parser.parse('Main')
        assert result is not None

        parser = Parser(rules=rules, input_str='  hello   world  ')
        result, _ = parser.parse('Main')
        assert result is not None

        parser = Parser(rules=rules, input_str='hello\n\tworld')
        result, _ = parser.parse('Main')
        assert result is not None

    def test_comment_handling_with_metagrammar(self) -> None:
        """comment handling with metagrammar"""
        grammar = '''
            # This is a comment
            Main <- "test"; # trailing comment
            # Another comment
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'Main' in rules

        parser = Parser(rules=rules, input_str='test')
        result, _ = parser.parse('Main')
        assert result is not None
