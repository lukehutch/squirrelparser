package javaparse.parboiled2;

import org.parboiled2._

class Parboiled2EqnParser(val input: ParserInput) extends Parser {
  def InputLine = rule { Expression ~ EOI }

  def Expression: Rule0 = rule { Prec0 }

  def Prec4 = rule { '(' ~ Prec0 ~ ')' }

  def Prec3 = rule { oneOrMore(CharPredicate.Digit) | Prec4 }

  def Prec2 = rule { ('-' ~ Prec3) | Prec3 }
  
  def Prec1 = rule { (Prec2 ~ '*' ~ Prec2 | Prec2 ~ '/' ~ Prec2) | Prec2 }
    
  def Prec0 : Rule0 = rule { (Prec1 ~ '+' ~ Prec1 | Prec1 ~ '-' ~ Prec1) | Prec1 }
}

object Parboiled2EqnParser {  
  def parse(input : String) = new Parboiled2EqnParser(input).InputLine.run()
}
