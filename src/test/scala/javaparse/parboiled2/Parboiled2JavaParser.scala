package javaparse.parboiled2;

import org.parboiled2._
import shapeless.HList

class Parboiled2JavaParser(val input: ParserInput) extends Parser {
    import Parboiled2JavaParser._
    def TopRule = rule { CompilationUnit ~ EOI }
    def CompilationUnit : Rule1[Node] = rule { (X ~ X) ~> Node2 }
    def X = rule { anyOf("x") ~> Node0 }
}

object Parboiled2JavaParser {
    def parse(input : String) = new Parboiled2JavaParser(input).TopRule.run()

    sealed trait Node
    case class Node0() extends Node
    case class NodeH2(h: HList) extends Node
    case class Node1(c0: Node) extends Node
    case class Node2(c0: Node, c1: Node) extends Node
    case class Node3(c0: Node, c1: Node, c2: Node) extends Node
    case class Node4(c0: Node, c1: Node, c2: Node, c3: Node) extends Node
    case class Node5(c0: Node, c1: Node, c2: Node, c3: Node, c4: Node) extends Node
    case class Node6(c0: Node, c1: Node, c2: Node, c3: Node, c4: Node, c5: Node) extends Node
    case class Node7(c0: Node, c1: Node, c2: Node, c3: Node, c4: Node, c5: Node, c6: Node) extends Node
    case class Node8(c0: Node, c1: Node, c2: Node, c3: Node, c4: Node, c5: Node, c6: Node, c7: Node) extends Node
    case class Node9(c0: Node, c1: Node, c2: Node, c3: Node, c4: Node, c5: Node, c6: Node, c7: Node, c8: Node) extends Node
    case class Leaf(str: String) extends Node
}