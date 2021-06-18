//
// This file is part of the squirrel parser reference implementation:
//
//     https://github.com/lukehutch/squirrelparser
//
// This software is provided under the MIT license:
//
// Copyright 2021 Luke A. D. Hutchison
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
package squirrelparser.grammar.clause;

/** A {@link Clause} with multiple subclauses. */
public abstract class ClauseWithMultipleSubClauses extends Clause {
    /** The subclauses of this {@link Clause}. */
    public final Clause[] subClauses;

    private final String toStringSeparator;

    protected ClauseWithMultipleSubClauses(String toStringSeparator, Clause... subClauses) {
        this.toStringSeparator = toStringSeparator;
        this.subClauses = subClauses;
    }

    @Override
    protected void visitSubclauses(SubClauseVisitor visitor) {
        for (int i = 0; i < subClauses.length; i++) {
            subClauses[i] = subClauses[i].visit(visitor);
        }
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        for (int i = 0; i < subClauses.length; i++) {
            if (i > 0) {
                buf.append(toStringSeparator);
            }
            buf.append(subClauseToString(subClauses[i]));
        }
        return labelClause(buf.toString());
    }
}