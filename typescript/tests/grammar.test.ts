import { MetaGrammar } from '../src/index.js';

describe('Grammar parsing', () => {
  it('parses simple grammar', () => {
    const simpleGrammar = `
      Test <- "hello";
    `;

    expect(() => MetaGrammar.parseGrammar(simpleGrammar)).not.toThrow();
  });

  it('parses multiline grammar', () => {
    const multilineGrammar = `
      JSON <- Value;
      Value <- "test";
    `;

    expect(() => MetaGrammar.parseGrammar(multilineGrammar)).not.toThrow();
  });
});
