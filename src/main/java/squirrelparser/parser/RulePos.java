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
package squirrelparser.parser;

import squirrelparser.grammar.clause.Clause;

///** The current rule being parsed, and the current position of the parser. */
//public record RulePos(Clause rule, int pos) {
//    @Override
//    public String toString() {
//        return rule + " : " + pos;
//    }
//}

public class RulePos {
    Clause rule;
    int pos;

    public RulePos(Clause rule, int pos) {
        this.rule = rule;
        this.pos = pos;
    }

    @Override
    public int hashCode() {
        return rule.hashCode() ^ pos;
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == this) {
            return true;
        }
        if (!(obj instanceof RulePos)) {
            return false;
        }
        var o = (RulePos) obj;
        return o.rule == this.rule && o.pos == this.pos;
    }

    public RulePos set(Clause rule, int pos) {
        this.rule = rule;
        this.pos = pos;
        return this;
    }
}