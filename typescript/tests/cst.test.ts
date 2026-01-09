import {
  CSTNode,
  CSTNodeFactory,
  CSTFactoryValidationException,
  DuplicateRuleNameException,
  MetaGrammar,
  squirrelParse,
} from '../src/index';
import { parseToMatchResultForTesting, parseWithRuleMapForTesting } from './testUtils';

// Simple test CST node for testing
class SimpleCST extends CSTNode {
  readonly children: CSTNode[];
  readonly value?: string;

  constructor(
    name: string,
    children: CSTNode[] = [],
    value?: string
  ) {
    super(name);
    this.children = children;
    this.value = value;
  }

  toString(): string {
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
        (ruleName: string, children: CSTNode[]) => {
          return new SimpleCST(ruleName, children as SimpleCST[]);
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
        (ruleName: string, _children: CSTNode[]) => {
          return new SimpleCST(ruleName);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'ExtraRule',
        (ruleName: string, _children: CSTNode[]) => {
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
        (ruleName: string, children: CSTNode[]) => {
          return new SimpleCST(ruleName, children as SimpleCST[]);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'Item',
        (ruleName: string, _children: CSTNode[]) => {
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
        (ruleName: string, _children: CSTNode[]) => {
          return new SimpleCST(ruleName, [], 'hello');
        }
      ),
    ];

    const [cst, errors] = squirrelParse(grammar, 'Test', factories, 'hello');

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
        (ruleName: string, _children: CSTNode[]) => {
          return new SimpleCST(ruleName);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'Main',
        (ruleName: string, _children: CSTNode[]) => {
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
        (ruleName: string, children: CSTNode[]) => {
          return new SimpleCST(ruleName, children as SimpleCST[]);
        }
      ),
      new CSTNodeFactory<SimpleCST>(
        'Term',
        (ruleName: string, _children: CSTNode[]) => {
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

