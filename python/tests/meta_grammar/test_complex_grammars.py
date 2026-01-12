"""Tests for MetaGrammar complex grammars."""

from squirrelparser import MetaGrammar, Parser


class TestComplexGrammars:
    """MetaGrammar - Complex Grammars tests."""

    def test_arithmetic_expression_grammar(self):
        grammar = '''
            Expr <- Term ("+" Term / "-" Term)*;
            Term <- Factor ("*" Factor / "/" Factor)*;
            Factor <- Number / "(" Expr ")";
            Number <- [0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Expr', rules=rules, input='42')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2

        parser = Parser(top_rule_name='Expr', rules=rules, input='1+2')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

        parser = Parser(top_rule_name='Expr', rules=rules, input='1+2*3')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 5

        parser = Parser(top_rule_name='Expr', rules=rules, input='(1+2)*3')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 7

    def test_identifier_and_keyword_grammar(self):
        grammar = '''
            Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
            Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Ident', rules=rules, input='foo')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Use match_rule for negative test to avoid recovery
        parser = Parser(top_rule_name='Ident', rules=rules, input='if')
        match_result = parser.match_rule('Ident', 0)
        assert match_result.is_mismatch  # 'if' is a keyword

        parser = Parser(top_rule_name='Ident', rules=rules, input='iffy')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None  # 'iffy' is not a keyword

    def test_json_grammar(self):
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

        parser = Parser(top_rule_name='Value', rules=rules, input='{}')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Value', rules=rules, input='[]')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Value', rules=rules, input='"hello"')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Value', rules=rules, input='123')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_whitespace_handling(self):
        grammar = r'''
            Main <- _ "hello" _ "world" _;
            _ <- [ \t\n\r]*;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Main', rules=rules, input='helloworld')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Main', rules=rules, input='  hello   world  ')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Main', rules=rules, input='hello\n\tworld')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_comment_handling_with_metagrammar(self):
        grammar = '''
            # This is a comment
            Main <- "test"; # trailing comment
            # Another comment
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'Main' in rules

        parser = Parser(top_rule_name='Main', rules=rules, input='test')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
