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
package squirrelparser.utils;

import java.awt.Color;
import java.awt.Font;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.io.ByteArrayOutputStream;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.PrintStream;
import java.util.regex.Pattern;

import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.WindowConstants;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;
import javax.swing.text.BadLocationException;
import javax.swing.text.DefaultHighlighter;
import javax.swing.text.Highlighter;
import javax.swing.text.Highlighter.HighlightPainter;

import squirrelparser.grammar.Grammar;
import squirrelparser.node.ASTNode;
import squirrelparser.parser.Parser;

public class ParsingWorkbench {

    private static JTextArea grammarPane = new JTextArea();
    private static Highlighter grammarHighlighter = grammarPane.getHighlighter();
    private static HighlightPainter syntaxErrorPainter = new DefaultHighlighter.DefaultHighlightPainter(Color.pink);
    private static HighlightPainter badRuleNamePainter = new DefaultHighlighter.DefaultHighlightPainter(Color.cyan);

    private static JTextArea inputPane = new JTextArea();
    private static Highlighter inputHighlighter = inputPane.getHighlighter();

    private static JTextArea parseTreePane = new JTextArea();

    private static JTextArea debugPane = new JTextArea();

    private static void parse() {
        var grammarStr = grammarPane.getText();
        var inputStr = inputPane.getText();

        inputHighlighter.removeAllHighlights();
        grammarHighlighter.removeAllHighlights();
        var grammar = (Grammar) null;
        try {
            grammar = MetaGrammar.parse(grammarStr);
        } catch (IllegalArgumentException e) {
            var m1 = Pattern.compile("syntax error location: ([0-9]+)").matcher(e.getMessage());
            if (m1.find()) {
                var syntaxErrorLoc = Integer.parseInt(m1.group(1));
                var start = Math.min(syntaxErrorLoc, grammarStr.length() - 1);
                var end = Math.min(start + 1, grammarStr.length());
                try {
                    grammarHighlighter.addHighlight(start, end, syntaxErrorPainter);
                } catch (BadLocationException e1) {
                }
            }
            var m2 = Pattern.compile("non-existent rule: (.+)").matcher(e.getMessage());
            if (m2.find()) {
                var badRuleName = m2.group(1);
                Pattern.compile("(" + badRuleName + ")").matcher(grammarStr).results().forEach(mr -> {
                    try {
                        grammarHighlighter.addHighlight(mr.start(), mr.end(), badRuleNamePainter);
                    } catch (BadLocationException e1) {
                    }
                });
            }
        }

        if (grammar != null) {
            var parser = new Parser(grammar);

            var baos = new ByteArrayOutputStream();
            System.setOut(new PrintStream(baos));
            Parser.DEBUG = true;
            var match = parser.parse(inputStr); // Parse input
            Parser.DEBUG = false;
            System.setOut(new PrintStream(new FileOutputStream(FileDescriptor.out)));
            debugPane.setText(baos.toString());

            var ast = (ASTNode) null;
            if (match.len < inputStr.length()) {
                var syntaxErrorLoc = MemoUtils.findMaxEndPos(parser);
                var start = Math.min(syntaxErrorLoc, grammarStr.length() - 1);
                var end = Math.min(start + 1, grammarStr.length());
                try {
                    inputHighlighter.addHighlight(start, end, syntaxErrorPainter);
                } catch (BadLocationException e1) {
                }
            } else {
                ast = new ASTNode(match, inputStr);
            }
            parseTreePane.setText("Parse tree:\n" + match.toStringWholeTree(inputStr) + "\n"
                    + (ast == null ? "(Parser did not match whole input)" : "AST:\n" + ast.toStringWholeTree()));
        }

    }

    public static void main(String[] args) {
        JFrame f = new JFrame();
        f.setSize(1200, 1000);
        f.setDefaultCloseOperation(WindowConstants.EXIT_ON_CLOSE);
        var p = new JPanel(new GridBagLayout());
        f.setContentPane(p);

        var c = new GridBagConstraints();

        var dl = new DocumentListener() {
            @Override
            public void insertUpdate(DocumentEvent e) {
                parse();
            }

            @Override
            public void removeUpdate(DocumentEvent e) {
                parse();
            }

            @Override
            public void changedUpdate(DocumentEvent e) {
            }
        };

        var font = new Font("Monospaced", Font.PLAIN, 12);
        
        c.gridx = 0;
        c.gridy = 0;
        c.weightx = .45;
        c.weighty = 0;
        c.fill = GridBagConstraints.HORIZONTAL;
        p.add(new JLabel("Grammar:"), c);
        c.gridx = 0;
        c.gridy = 1;
        c.weightx = .45;
        c.weighty = .5;
        c.fill = GridBagConstraints.BOTH;
        p.add(new JScrollPane(grammarPane), c);
        grammarPane.getDocument().addDocumentListener(dl);
        grammarPane.setFont(font);

        c.gridx = 1;
        c.gridy = 0;
        c.weightx = .55;
        c.weighty = 0;
        c.fill = GridBagConstraints.HORIZONTAL;
        p.add(new JLabel("Input:"), c);
        c.gridx = 1;
        c.gridy = 1;
        c.weightx = .55;
        c.weighty = .5;
        c.fill = GridBagConstraints.BOTH;
        p.add(new JScrollPane(inputPane), c);
        inputPane.getDocument().addDocumentListener(dl);
        inputPane.setFont(font);

        c.gridx = 0;
        c.gridy = 2;
        c.weightx = .45;
        c.weighty = 0;
        c.fill = GridBagConstraints.HORIZONTAL;
        p.add(new JLabel("Parse tree and AST:"), c);
        c.gridx = 0;
        c.gridy = 3;
        c.weightx = .45;
        c.weighty = 1;
        c.fill = GridBagConstraints.BOTH;
        p.add(new JScrollPane(parseTreePane), c);
        parseTreePane.setEditable(false);
        parseTreePane.setFont(font);

        c.gridx = 1;
        c.gridy = 2;
        c.weightx = .55;
        c.weighty = 0;
        c.fill = GridBagConstraints.HORIZONTAL;
        p.add(new JLabel("Debug:"), c);
        c.gridx = 1;
        c.gridy = 3;
        c.weightx = .55;
        c.weighty = 1;
        c.fill = GridBagConstraints.BOTH;
        p.add(new JScrollPane(debugPane), c);
        debugPane.setEditable(false);
        debugPane.setFont(font);

        f.setLocationRelativeTo(null);
        f.setVisible(true);
    }
}
