import {
  ASTNode,
  CSTNode,
  squirrelParseCST,
} from '../src/index.js';

// ============================================================================
// Custom CST Node Classes for Testing
// ============================================================================

/**
 * A simple CST node that includes all its children.
 */
class InclusiveNode extends CSTNode {
  readonly computedValue: string | undefined;

  constructor(astNode: ASTNode, children: readonly CSTNode[], computedValue?: string) {
    super(astNode, children);
    this.computedValue = computedValue;
  }
}

/**
 * A CST node that computes from children without storing them.
 */
class ComputedNode extends CSTNode {
  readonly childCount: number;
  readonly concatenated: string;

  constructor(astNode: ASTNode, _children: readonly CSTNode[], childCount: number, concatenated: string) {
    super(astNode, []);
    this.childCount = childCount;
    this.concatenated = concatenated;
  }
}

/**
 * A CST node that transforms children.
 */
class TransformedNode extends CSTNode {
  readonly transformedLabels: string[];

  constructor(astNode: ASTNode, children: readonly CSTNode[], transformedLabels: string[]) {
    super(astNode, children);
    this.transformedLabels = transformedLabels;
  }
}

/**
 * A CST node that selects specific children.
 */
class SelectiveNode extends CSTNode {
  readonly selectedChildren: readonly CSTNode[];

  constructor(astNode: ASTNode, _children: readonly CSTNode[], selectedChildren: readonly CSTNode[]) {
    super(astNode, selectedChildren);
    this.selectedChildren = selectedChildren;
  }
}

/**
 * A CST node for terminals.
 */
class TerminalNode extends CSTNode {
  readonly text: string;

  constructor(astNode: ASTNode, text: string) {
    super(astNode, []);
    this.text = text;
  }
}

/**
 * A CST node for syntax errors.
 */
class ErrorNode extends CSTNode {
  readonly errorMessage: string;

  constructor(astNode: ASTNode, errorMessage: string) {
    super(astNode, []);
    this.errorMessage = errorMessage;
  }
}

describe('CST/AST Creation Scenarios', () => {
  // ========================================================================
  // Scenario 1: Factory includes all children (inclusive)
  // ========================================================================

  it('factory includes all children', () => {
    const grammar = `
      Expr <- Term ('+' Term)*;
      Term <- [0-9]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Expr',
      factories: [
        {
          ruleName: 'Expr',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: 'Term',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
      ],
      input: '1+2',
    });

    expect(cst).not.toBeNull();
    expect(cst).toBeInstanceOf(InclusiveNode);
    expect(cst.label).toBe('Expr');
    expect(cst.children.length).toBeGreaterThan(0);
  });

  // ========================================================================
  // Scenario 2: Factory computes from children without storing them
  // ========================================================================

  it('factory computes from children without storing them', () => {
    const grammar = `
      Sum <- Number ('+' Number)*;
      Number <- [0-9]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Sum',
      factories: [
        {
          ruleName: 'Sum',
          factory: (astNode, children) => {
            const childCount = children.length;
            const concatenated = children.map((c) => c.label).join(',');
            return new ComputedNode(astNode, children, childCount, concatenated);
          },
        },
        {
          ruleName: 'Number',
          factory: (astNode, children) => new ComputedNode(astNode, children, 0, 'Number'),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, children) => new ComputedNode(astNode, children, 0, 'Terminal'),
        },
      ],
      input: '42',
    });

    expect(cst).not.toBeNull();
    expect(cst).toBeInstanceOf(ComputedNode);
    const computed = cst as ComputedNode;
    expect(computed.childCount).not.toBeNull();
    expect(computed.concatenated).not.toBe('');
  });

  // ========================================================================
  // Scenario 3: Factory transforms children
  // ========================================================================

  it('factory transforms children', () => {
    const grammar = `
      List <- Element (',' Element)*;
      Element <- [a-z]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'List',
      factories: [
        {
          ruleName: 'List',
          factory: (astNode, children) => {
            const labels = children.map((c) => c.label.toUpperCase());
            return new TransformedNode(astNode, [...children], labels);
          },
        },
        {
          ruleName: 'Element',
          factory: (astNode, children) => new TransformedNode(astNode, [...children], ['ELEMENT']),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, children) => new TransformedNode(astNode, [...children], ['TERMINAL']),
        },
      ],
      input: 'abc',
    });

    expect(cst).not.toBeNull();
    expect(cst).toBeInstanceOf(TransformedNode);
    const transformed = cst as TransformedNode;
    expect(transformed.transformedLabels.length).toBeGreaterThan(0);
  });

  // ========================================================================
  // Scenario 4: Factory selects specific children
  // ========================================================================

  it('factory selects specific children', () => {
    const grammar = `
      Pair <- '(' First ',' Second ')';
      First <- [a-z]+;
      Second <- [0-9]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Pair',
      factories: [
        {
          ruleName: 'Pair',
          factory: (astNode, children) => {
            // Only keep First and Second, skip terminals
            const selected = children.filter((c) => c.label === 'First' || c.label === 'Second');
            return new SelectiveNode(astNode, children, selected);
          },
        },
        {
          ruleName: 'First',
          factory: (astNode, children) => new SelectiveNode(astNode, children, children),
        },
        {
          ruleName: 'Second',
          factory: (astNode, children) => new SelectiveNode(astNode, children, children),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, children) => new SelectiveNode(astNode, children, []),
        },
      ],
      input: '(abc,123)',
    });

    expect(cst).not.toBeNull();
    expect(cst).toBeInstanceOf(SelectiveNode);
    const selective = cst as SelectiveNode;
    // Should have 2 selected children: First and Second
    expect(selective.selectedChildren.length).toBe(2);
  });

  // ========================================================================
  // Scenario 5: Terminal handling
  // ========================================================================

  it('terminals are handled by factory', () => {
    const grammar = `
      Text <- Word;
      Word <- [a-z]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Text',
      factories: [
        {
          ruleName: 'Text',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: 'Word',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, _children) => new TerminalNode(astNode, 'terminal'),
        },
      ],
      input: 'hello',
    });

    expect(cst).not.toBeNull();
    // Text should have Word children, which have terminal children
    expect(cst.children.length).toBeGreaterThan(0);
  });

  // ========================================================================
  // Scenario 6: Syntax error handling
  // ========================================================================

  it('syntax errors are handled when allowSyntaxErrors is true', () => {
    const grammar = `
      Expr <- Number;
      Number <- [0-9]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Expr',
      factories: [
        {
          ruleName: 'Expr',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: 'Number',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: '<SyntaxError>',
          factory: (astNode, _children) => new ErrorNode(astNode, `Syntax error at ${astNode.pos}`),
        },
      ],
      input: 'abc',
      allowSyntaxErrors: true,
    });

    expect(cst).not.toBeNull();
    // With syntax errors allowed, we should get an error node
  });

  // ========================================================================
  // Scenario 7: Nested structures with mixed approaches
  // ========================================================================

  it('nested structures with mixed factory approaches', () => {
    const grammar = `
      Doc <- Section+;
      Section <- Title;
      Title <- [a-z]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Doc',
      factories: [
        // Inclusive factory
        {
          ruleName: 'Doc',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        // Selective factory
        {
          ruleName: 'Section',
          factory: (astNode, children) => {
            const selected = children.filter((c) => c.label === 'Title');
            return new SelectiveNode(astNode, children, selected);
          },
        },
        // Computed factory
        {
          ruleName: 'Title',
          factory: (astNode, children) => new ComputedNode(astNode, children, children.length, 'Title'),
        },
        // Terminal factory
        {
          ruleName: '<Terminal>',
          factory: (astNode, _children) => new TerminalNode(astNode, 'terminal'),
        },
      ],
      input: 'abc',
    });

    expect(cst).not.toBeNull();
    expect(cst).toBeInstanceOf(InclusiveNode);
  });

  // ========================================================================
  // Scenario 8: Empty alternatives and optional matching
  // ========================================================================

  it('handles optional matches without errors', () => {
    const grammar = `
      Sentence <- Word (' ' Word)*;
      Word <- [a-z]+;
    `;

    const cst = squirrelParseCST({
      grammarSpec: grammar,
      topRuleName: 'Sentence',
      factories: [
        {
          ruleName: 'Sentence',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: 'Word',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
        {
          ruleName: '<Terminal>',
          factory: (astNode, children) => new InclusiveNode(astNode, children),
        },
      ],
      input: 'hello world test',
    });

    expect(cst).not.toBeNull();
  });
});
