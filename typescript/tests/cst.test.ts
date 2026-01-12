import {
  ASTNode,
  CSTNode,
  CSTNodeFactory,
  squirrelParseCST,
  squirrelParsePT,
} from '../src/index.js';

/**
 * Simple test CST node for testing.
 */
class SimpleCST extends CSTNode {
  readonly value: string | undefined;

  constructor(astNode: ASTNode, children: readonly CSTNode[], value?: string) {
    super(astNode, children);
    this.value = value;
  }
}

describe('CST - Concrete Syntax Tree', () => {
  it('parse tree methods exist and work', () => {
    const grammar = `
      Greeting <- "hello" Name;
      Name <- [a-z]+;
    `;

    const parseResult = squirrelParsePT({
      grammarSpec: grammar,
      topRuleName: 'Greeting',
      input: 'helloworld',
    });

    expect(parseResult).not.toBeNull();
    expect(parseResult.root.isMismatch).toBe(false);
    expect(parseResult.getSyntaxErrors()).toHaveLength(0);
  });

  it('CST factory validation catches missing factories', () => {
    const grammar = `
      Greeting <- "hello" Name;
      Name <- [a-z]+;
    `;

    // Only provide factory for Greeting, missing Name and <Terminal>
    const factories: CSTNodeFactory[] = [
      {
        ruleName: 'Greeting',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
    ];

    expect(() =>
      squirrelParseCST({
        grammarSpec: grammar,
        topRuleName: 'Greeting',
        factories,
        input: 'hello world',
      })
    ).toThrow();
  });

  it('CST factory validation catches extra factories', () => {
    const grammar = `
      Greeting <- "hello";
    `;

    // Provide factory for Greeting and extra Name
    const factories: CSTNodeFactory[] = [
      {
        ruleName: 'Greeting',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
      {
        ruleName: 'ExtraRule',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
    ];

    expect(() =>
      squirrelParseCST({
        grammarSpec: grammar,
        topRuleName: 'Greeting',
        factories,
        input: 'hello',
      })
    ).toThrow();
  });

  it('basic CST construction works', () => {
    const grammar = `
      Main <- Item;
      Item <- "test";
    `;

    const factories: CSTNodeFactory[] = [
      {
        ruleName: 'Main',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
      {
        ruleName: 'Item',
        factory: (astNode, children) => new SimpleCST(astNode, children, 'test'),
      },
      {
        ruleName: '<Terminal>',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
    ];

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Main',
      factories,
      input: 'test',
    });

    expect(cst).not.toBeNull();
    expect(cst.label).toBe('Main');
  });

  it('squirrelParse is the main public API', () => {
    const grammar = `
      Test <- "hello";
    `;

    const factories: CSTNodeFactory[] = [
      {
        ruleName: 'Test',
        factory: (astNode, children) => new SimpleCST(astNode, children, 'hello'),
      },
      {
        ruleName: '<Terminal>',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
    ];

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Test',
      factories,
      input: 'hello',
    });

    expect(cst).not.toBeNull();
    expect(cst.label).toBe('Test');
  });

  it('duplicate rule names throw error', () => {
    const grammar = `
      Main <- "test";
    `;

    // Provide two factories with the same rule name
    const factories: CSTNodeFactory[] = [
      {
        ruleName: 'Main',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
      {
        ruleName: 'Main',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
    ];

    expect(() =>
      squirrelParseCST({
        grammarSpec: grammar,
        topRuleName: 'Main',
        factories,
        input: 'test',
      })
    ).toThrow();
  });

  it('transparent rules are excluded from CST factories', () => {
    const grammar = `
      Expr <- ~Whitespace Term ~Whitespace;
      ~Whitespace <- ' '*;
      Term <- "x";
    `;

    // Should only need factories for Expr and Term, not Whitespace (which is transparent)
    const factories: CSTNodeFactory[] = [
      {
        ruleName: 'Expr',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
      {
        ruleName: 'Term',
        factory: (astNode, children) => new SimpleCST(astNode, children, 'x'),
      },
      {
        ruleName: '<Terminal>',
        factory: (astNode, children) => new SimpleCST(astNode, children),
      },
    ];

    // This should work without a factory for Whitespace
    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Expr',
      factories,
      input: ' x ',
    });

    expect(cst).not.toBeNull();
  });
});
