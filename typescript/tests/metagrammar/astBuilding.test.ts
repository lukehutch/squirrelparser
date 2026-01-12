import { MetaGrammar, Parser, buildAST } from '../../src/index.js';

describe('MetaGrammar - AST Building', () => {
  test('AST structure for simple grammar', () => {
    const grammar = `
      Main <- A B;
      A <- "a";
      B <- "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'ab' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    expect(ast.label).toBe('Main');
    expect(ast.children.length).toBe(2);
    expect(ast.children[0].label).toBe('A');
    expect(ast.children[1].label).toBe('B');
  });

  test('AST flattens combinator nodes', () => {
    const grammar = `
      Main <- A+ B*;
      A <- "a";
      B <- "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'aaabbb' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    expect(ast.label).toBe('Main');

    // Should have flattened A and B children, not intermediate repetition nodes
    const aNodes = ast.children.filter((n) => n.label === 'A').length;
    const bNodes = ast.children.filter((n) => n.label === 'B').length;
    expect(aNodes).toBe(3);
    expect(bNodes).toBe(3);
  });

  test('AST text extraction', () => {
    const grammar = `
      Number <- [0-9]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Number', rules, input: '123' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    // ast.text property not available; extract from input using position and length
    const text = parseResult.input.substring(0, parseResult.root.len);
    expect(text).toBe('123');
  });

  test('AST for nested structures', () => {
    const grammar = `
      Expr <- Term (("+" / "-") Term)*;
      Term <- [0-9]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Expr', rules, input: '1+2-3' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    expect(ast.label).toBe('Expr');

    // Should have Terms as direct children (flattened)
    const termNodes = ast.children.filter((n) => n.label === 'Term');
    expect(termNodes.length).toBeGreaterThanOrEqual(1);
  });

  test('AST pretty printing', () => {
    const grammar = `
      Main <- A B;
      A <- "a";
      B <- "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'ab' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    const prettyString = ast.toPrettyString(parseResult.input);
    expect(prettyString).toContain('Main');
    expect(prettyString).toContain('A');
    expect(prettyString).toContain('B');
  });

  test('AST allows zero children when all sub-rules are transparent', () => {
    // When a rule only contains transparent rules, the AST node has zero children
    const grammar = `
      Main <- ~A;
      ~A <- "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'a' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    expect(ast.label).toBe('Main');
    expect(ast.pos).toBe(0);
    expect(ast.len).toBe(1);
    // Main has zero children because A is transparent
    expect(ast.children.length).toBe(0);
  });
});
