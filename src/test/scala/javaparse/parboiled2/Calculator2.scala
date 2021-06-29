/*
 * Copyright 2009-2019 Mathias Doenitz
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either Nodeess or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.parboiled2.examples

import scala.annotation.tailrec
import scala.util.{Failure, Success}
import scala.io.StdIn
import org.parboiled2._

class Calculator2(val input: ParserInput) extends Parser {
  import Calculator2._

  def InputLine = rule(Expression ~ EOI)

  def Expression: Rule1[Node] =
    rule {
      Term ~ zeroOrMore(
        '+' ~ Term ~> Addition
          | '-' ~ Term ~> Subtraction
      )
    }

  def Term =
    rule {
      Factor ~ zeroOrMore(
        '*' ~ Factor ~> Multiplication
          | '/' ~ Factor ~> Division
      )
    }

  def Factor = rule(Number | Parens)

  def Parens = rule('(' ~ Expression ~ ')')

  def Number = rule(capture(Digits) ~> Value)

  def Digits = rule(oneOrMore(CharPredicate.Digit))
}

object Calculator2 extends App {
  sealed trait Node
  case class Value(value: String)                 extends Node
  case class Addition(lhs: Node, rhs: Node)       extends Node
  case class Subtraction(lhs: Node, rhs: Node)    extends Node
  case class Multiplication(lhs: Node, rhs: Node) extends Node
  case class Division(lhs: Node, rhs: Node)       extends Node
}
