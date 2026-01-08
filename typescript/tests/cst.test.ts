import {
  CSTNode,
  CSTNodeFactory,
  CSTFactoryValidationException,
  DuplicateRuleNameException,
  MetaGrammar,
  squirrelParse,
  parseToMatchResultForTesting,
  parseWithRuleMapForTesting,
} from '../src/index';

// Simple test CST node for testing
class SimpleCST extends CSTNode {
  constructor(
    name: string,
    readonly children: CSTNode[] = [],
    readonly value?: string
  ) {
    super(name);
  }

  override toString(): string {
    return this.value ?? this.name;
  }
}

describe('CST - Concrete Syntax Tree', () => {
  test('parse tree methods exist and work', () => {
    const grammar = `
      Greeting <- "hello" Name;
      Name <- [a-z]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const [pt, errors] = parseToMatchResultForTesting(rules, 'Greeting', 'helloworld');

    expect(pt).not.toBeNull();
    expect(pt.isMismatch).toBe(false);
    expect(errors).toEqual([]);
  });

  test('CST factory validation catches missing factories', () => {
    const grammar = `
      Greeting <- "hello" Name;
      Name <- [a-z]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Only provide factory for Greeting, missing Name
    const factories = [
      new CSTNodeFactory<SimpleCST>(
        'Greeting',
        ['Name'],
        (ruleName, expectedChildren, children) => {
          return new SimpleCST(ruleName, children);
        }
      ),
    ];

    expect(() => {
      parseWithRuleMapForTesting(rules, 'Greeting', 'hello world', factories);
    }).toThrow(CSTFactoryValidationException);
  });

  test('CST factory validation catches extra factories', () => {
    const grammar = `
      Greeting <- "hello";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Provide factory for Greeting and extra Name
    const factories = [
      new CSTNodeFactory<SimpleCST>(
        'Greeting',
        [],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'ExtraRule',
        [],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName);
        }
      ),
    ];

    expect(() => {
      parseWithRuleMapForTesting(rules, 'Greeting', 'hello', factories);
    }).toThrow(CSTFactoryValidationException);
  });

  test('basic CST construction works', () => {
    const grammar = `
      Main <- Item;
      Item <- "test";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    const factories = [
      new CSTNodeFactory<SimpleCST>(
        'Main',
        ['Item'],
        (ruleName, _expectedChildren, children) => {
          return new SimpleCST(ruleName, children);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'Item',
        ['<Terminal>'],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName, [], 'test');
        }
      ),
    ];

    const [cst, errors] = parseWithRuleMapForTesting(rules, 'Main', 'test', factories);

    expect(cst).not.toBeNull();
    expect(cst.name).toBe('Main');
    expect(errors).toEqual([]);
  });

  test('squirrelParse is the main public API', () => {
    const grammar = `
      Test <- "hello";
    `;

    const factories = [
      new CSTNodeFactory<SimpleCST>(
        'Test',
        ['<Terminal>'],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName, [], 'hello');
        }
      ),
    ];

    const [cst, errors] = squirrelParse(grammar, 'hello', 'Test', factories);

    expect(cst).not.toBeNull();
    expect(cst.name).toBe('Test');
    expect(errors).toEqual([]);
  });

  test('duplicate rule names throw DuplicateRuleNameException', () => {
    const grammar = `
      Main <- "test";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Provide two factories with the same rule name
    const factories = [
      new CSTNodeFactory<SimpleCST>(
        'Main',
        [],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'Main',
        [],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName);
        }
      ),
    ];

    expect(() => {
      parseWithRuleMapForTesting(rules, 'Main', 'test', factories);
    }).toThrow(DuplicateRuleNameException);
  });

  test('transparent rules are excluded from CST factories', () => {
    const grammar = `
      Expr <- ~Whitespace Term ~Whitespace;
      ~Whitespace <- ' '*;
      Term <- "x";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Should only need factories for Expr and Term, not Whitespace (which is transparent)
    const factories = [
      new CSTNodeFactory<SimpleCST>(
        'Expr',
        ['Term'],
        (ruleName, _expectedChildren, children) => {
          return new SimpleCST(ruleName, children);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'Term',
        ['<Terminal>'],
        (ruleName, _expectedChildren, _children) => {
          return new SimpleCST(ruleName, [], 'x');
        }
      ),
    ];

    // This should work without a factory for Whitespace
    const [cst, errors] = parseWithRuleMapForTesting(rules, 'Expr', ' x ', factories);

    expect(cst).not.toBeNull();
    expect(errors).toEqual([]);
  });
});
