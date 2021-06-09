grammar Equation;

@header { package eqn.antlr; }

eqn : prec0;
prec4 : OPEN prec0 CLOSE;
prec3 : NUM | prec4;
prec2 : (MINUS prec3) | prec3;
prec1 : (prec2 (TIMES | DIV) prec2) | prec2;
prec0 : (prec1 (PLUS | MINUS) prec1) | prec1;

NUM : [0-9]+;
OPEN : '(';
CLOSE : ')';
PLUS : '+';
MINUS : '-';
TIMES : '*';
DIV : '/';
