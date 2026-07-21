# TOPLAS editor-suggested papers + ANTLR citation verification

Date: 2026-07-20. All metadata below verified against Crossref (api.crossref.org) and DBLP
(dblp.org .bib records); full texts obtained where noted. PDFs and extracted .txt files are in
this scratchpad directory (mgll.pdf/.txt, jourdan2017.pdf/.txt, allstar.pdf/.txt, llstar.pdf/.txt).

---

## 1. DOI 10.1145/3594734 — Scott, Johnstone, Walsh (2023), "Multiple Input Parsing and Lexical Analysis"

**Identification (confirmed via Crossref + DBLP journals/toplas/ScottJW23):**
Elizabeth Scott, Adrian Johnstone, Robert Walsh. TOPLAS Vol. 45, No. 3, Article 14, 44 pages,
July/September 2023. Full text obtained (bronze OA PDF from dl.acm.org, saved as mgll.pdf).

### (a) BibTeX (DBLP-verified)
```bibtex
@article{DBLP:journals/toplas/ScottJW23,
  author       = {Elizabeth Scott and
                  Adrian Johnstone and
                  Robert Walsh},
  title        = {Multiple Input Parsing and Lexical Analysis},
  journal      = {{ACM} Trans. Program. Lang. Syst.},
  volume       = {45},
  number       = {3},
  pages        = {14:1--14:44},
  year         = {2023},
  url          = {https://doi.org/10.1145/3594734},
  doi          = {10.1145/3594734}
}
```

### (b) Summary and structure/rigor
Introduces MGLL, an extension of GLL generalised parsing that parses a *set* of input strings
simultaneously, and uses this to make lexical analysis flexible: the lexer emits a "TWE set"
(Tokens With Extents) encoding *all* possible lexicalisations of the character stream, and the
multi-parser resolves lexical ambiguity at parse level — spanning character-level parsing at
one extreme and classical LEX/YACC at the other. The 44-page article is explicitly organized
in three parts: Part 1 (formal machinery: TWE sets, "tight" sets, ESPPF shared packed parse
forests), Part 2 (the MGLL algorithm — pitched as the primary contribution), Part 3
(practicalities + a Java case study). Rigor: full formal development with definitions,
Lemmas 1–3 and Theorem 1 in the main text and complete proofs in an appendix, plus
pseudo-code for the algorithms. Empirical side: an "initial evaluation" using the Java
language specification in their ART tool, with a careful timing regime (30 runs per
experiment, hardware/JVM methodology section 9.2); the authors explicitly scope this as
baseline practicality, stating "A full evaluation of implementation strategies and runtime
costs will only emerge as the technique is used more widely in the community."
Calibration takeaway: TOPLAS accepts theory-first parsing papers where the formal
contribution carries the paper and the evaluation is a single-language case study — but the
formalism is complete (all proofs given) and the evaluation methodology is meticulous.

### (c) Topical relation
- (i) PEG/packrat: **No** (GLL/generalised CFG parsing). PEGs appear only once, in the
  evaluation discussion, dismissed as "more general but still limited techniques" that
  construct only one derivation.
- (ii) Left recursion: **Peripheral.** GLL handles all CFGs including left recursion; the text
  mentions Tomita's error on "hidden left recursion" in passing. Not a topic of the paper.
- (iii) Syntax error recovery: **No.** No error recovery content.
- **Cite?** Not obligatory for a PEG/left-recursion/error-recovery paper, but cheap and wise
  to cite given the editor pointed at it: fits naturally in related work as the
  state-of-the-art generalised (GLL-family) parsing line at TOPLAS, contrasted with PEG's
  ordered choice (the paper itself makes that contrast). Also relevant if we discuss
  scannerless/character-level parsing.

### (d) Verbatim quotes (from full text, mgll.txt)
1. "This article introduces two new approaches in the areas of lexical analysis and
   context-free parsing. We present an extension, MGLL, of generalised parsing which allows
   multiple input strings to be parsed together efficiently, and we present an enhanced
   approach to lexical analysis which exploits this multiple parsing capability." (Abstract)
2. "We cannot compare the multi-lexer approach with traditional Lex/Yacc technology, or with
   more general but still limited techniques such as PEGs [8] or the extended look-ahead
   LL(*) [17] approach. These do not even provide multiple derivations of one input sentence:
   at each step, phrase-level ambiguity is 'resolved' by selecting one derivation to proceed
   with ... or by selecting the first successful match in the case of PEGs." (Section 9)

---

## 2. DOI 10.1145/3064848 — Jourdan & Pottier (2017), "A Simple, Possibly Correct LR Parser for C11"

**Identification (confirmed via Crossref + DBLP journals/toplas/JourdanP17):**
Jacques-Henri Jourdan, François Pottier. TOPLAS Vol. 39, No. 4, Article 14, 36 pages,
August/December 2017. Full text obtained (green OA from HAL: hal-01633123, saved as
jourdan2017.pdf).

### (a) BibTeX (DBLP-verified)
```bibtex
@article{DBLP:journals/toplas/JourdanP17,
  author       = {Jacques{-}Henri Jourdan and
                  Fran{\c{c}}ois Pottier},
  title        = {A Simple, Possibly Correct {LR} Parser for {C11}},
  journal      = {{ACM} Trans. Program. Lang. Syst.},
  volume       = {39},
  number       = {4},
  pages        = {14:1--14:36},
  year         = {2017},
  url          = {https://doi.org/10.1145/3064848},
  doi          = {10.1145/3064848}
}
```

### (b) Summary and structure/rigor
Tackles the notoriously messy problem of parsing C11 — an ambiguous grammar in the standard
plus prose-defined "scope" and the typedef/identifier ("lexer hack") ambiguity — with an
LALR(1) parser (Menhir) plus a refined lexical-feedback mechanism: a twist that makes
feedback interact correctly with lookahead, a simplified treatment of scopes, and small
grammar amendments. The paper is an *engineering/experience* paper: Section 2 catalogs the
challenges with tricky C programs, Section 3 presents the parser (under 500 lines of grammar
+ ~400 lines support code, a simplified version of CompCert's pre-parser), Sections 4–5 are
related work and conclusion. Rigor: **zero theorems or formal proofs** — the title's
"possibly correct" is the pitch; the authors argue correctness informally via simplicity,
declarativity, similarity to the C11 grammar, and a "torture test" suite of tricky C11
programs, while explicitly noting the parser is "not formally verified" and "has not been
extensively tested." No performance evaluation. Calibration takeaway: TOPLAS also accepts
careful, honest engineering papers with *no* proofs and *no* benchmarks, provided the problem
is real, the solution is unusually clean, and the epistemic status of every claim is candid —
candor about limits is itself part of the accepted style.

### (c) Topical relation
- (i) PEG/packrat: **Peripheral.** Related-work Section 4 discusses Grimm's Rats! PEG parser
  generator for C (ordered choice, syntactic predicates, memoized linear time) — one
  paragraph only.
- (ii) Left recursion: **No** (LR parsing; left recursion is a non-issue).
- (iii) Syntax error recovery: **No.** Not addressed.
- **Cite?** Optional. Natural fit only if our paper uses C/typedef context-sensitivity as a
  motivating example or discusses how PEG ordered choice sidesteps ambiguity that LR must
  resolve via lexical feedback. Otherwise a courtesy cite in related work.

### (d) Verbatim quotes (from full text, jourdan2017.txt)
1. "Although not formally verified, our parser avoids several pitfalls that other
   implementations have fallen prey to. We believe that its simplicity, its mostly-declarative
   nature, and its high similarity with the C11 grammar are strong informal arguments in favor
   of its correctness." (Abstract)
2. "The C11 parsers found in popular compilers, such as GCC and Clang, are very likely
   correct, but their size is in the tens of thousands of lines. Therefore, we believe that
   there is a need for a simple reference implementation that is easy to adopt and extend."
   (Conclusion, Section 5)

---

## 3. DOI 10.1145/200994.200996 — Larchevêque (1995), "Optimal Incremental Parsing"

**Identification (confirmed via Crossref + DBLP journals/toplas/Larcheveque95):**
Jean-Marie Larchevêque. TOPLAS Vol. 17, No. 1, pages 1–15, January 1995.
**Full text NOT reachable** — ACM DL PDF is paywalled (curl returned an HTML block page;
no green OA copy found via Semantic Scholar, Unpaywall status, or web search). Everything
below is from the Crossref-supplied abstract plus citing literature; summary is therefore
partially inferred, as flagged.

### (a) BibTeX (DBLP-verified)
```bibtex
@article{DBLP:journals/toplas/Larcheveque95,
  author       = {Jean{-}Marie Larchev{\^{e}}que},
  title        = {Optimal Incremental Parsing},
  journal      = {{ACM} Trans. Program. Lang. Syst.},
  volume       = {17},
  number       = {1},
  pages        = {1--15},
  year         = {1995},
  url          = {https://doi.org/10.1145/200994.200996},
  doi          = {10.1145/200994.200996}
}
```

### (b) Summary and structure/rigor (abstract-based; full-text claims inferred)
Places incremental parsing in the context of a complete incremental compiling system (parser
feeding an incremental attribute evaluator / data-flow analyzer), observes that two distinct
definitions of "optimal incrementality" arise depending on the downstream consumer's
incrementality paradigm, and gives algorithms achieving *both* forms of optimality using
ordinary LALR(1) parse tables — i.e., no special table construction. The formal backbone is
the notion of a "well-formed list of threaded trees," extending the threaded-tree concept of
earlier incremental-parsing work, which the abstract says makes the optimality and
correctness proofs "intuitive." Rigor: the abstract itself calls the paper a "communication"
(it is only 15 pages) and states that optimality and correctness proofs "are merely outlined"
— i.e., proof sketches, not full proofs. Calibration takeaway (inferred from abstract):
mid-90s TOPLAS accepted short communications where theorems are stated with outlined proofs;
note this is a 1995 bar, and the two modern examples above (full appendix proofs, or total
candor with zero proofs) are the better calibration targets. This paper is the canonical
"optimal incrementality" reference in the incremental-parsing literature (cited by
Wagner & Graham's "Efficient and flexible incremental parsing," TOPLAS 1998, and by
Dubroy & Warth's "Incremental packrat parsing," SLE 2017).

### (c) Topical relation
- (i) PEG/packrat: **No** (LALR(1)). But it is upstream related work for *incremental packrat
  parsing* (Dubroy & Warth SLE'17 cite it).
- (ii) Left recursion: **No.**
- (iii) Syntax error recovery: **No** directly — but incremental re-parse after edits is
  adjacent to our planned incremental re-parse work (see memory: recovery next steps), and
  error recovery and incrementality are the two classic "IDE parsing" requirements.
- **Cite?** Yes, if the paper discusses incremental re-parsing (planned future work / IDE
  motivation) — it is the standard "optimal incremental parsing" citation. Skip if we cut
  all incremental discussion.

### (d) Verbatim quote (from publisher-supplied abstract only; full text unreachable)
1. "Algorithms for achieving both forms of optimality are given, both of them based on
   ordinary LALR(1) parse tables. Optimality and correctness proofs, which are merely
   outlined in this communication, are made intuitive thanks to the concept of a well-formed
   list of threaded trees." (Abstract, via Crossref)

---

## 4. Verification: Parr, Harwell, Fisher 2014, "Adaptive LL(*) Parsing: The Power of Dynamic Analysis" (OOPSLA'14)

**Metadata CONFIRMED** via Crossref + DBLP conf/oopsla/ParrHF14: Terence Parr, Sam Harwell,
Kathleen Fisher; Proceedings of OOPSLA 2014 (SPLASH), pages 579–598, ACM, Oct 2014;
DOI 10.1145/2660193.2660202. (DBLP title capitalization: "Adaptive LL(*) parsing: the power
of dynamic analysis".) Full text obtained: antlr.org tech-report version
(https://www.antlr.org/papers/allstar-techreport.pdf, saved as allstar.pdf) — quotes below
are from that version; wording matches the published abstract.

```bibtex
@inproceedings{DBLP:conf/oopsla/ParrHF14,
  author       = {Terence Parr and Sam Harwell and Kathleen Fisher},
  title        = {Adaptive LL(*) parsing: the power of dynamic analysis},
  booktitle    = {Proceedings of the 2014 {ACM} International Conference on Object Oriented
                  Programming Systems Languages {\&} Applications, {OOPSLA} 2014},
  pages        = {579--598},
  publisher    = {{ACM}},
  year         = {2014},
  doi          = {10.1145/2660193.2660202}
}
```

**Both of our claims VERIFIED verbatim:**
- Direct-left-recursion-only via rewriting: "The ALL(*) parsing strategy itself does not
  support left-recursion, but ANTLR supports direct left-recursion through grammar rewriting
  prior to parser generation. ... We made an engineering decision not to support indirect or
  hidden left-recursion" (Section 2.2, "Left-recursion removal"). Also footnote 2 defines
  indirect/hidden left recursion, and Theorem 6.5 is scoped to "non-left-recursive G".
- Worst case O(n^4): Abstract: "ALL(*) is O(n4) in theory but consistently performs linearly
  on grammars used in practice"; Section 7: "We have yet to see nonlinear behavior in practice
  but the theoretical worst-case behavior of ALL(*) parsing is O(n4). Experimental parse-time
  data for the following contrived worst-case grammar exhibits quartic behavior ...
  S → A $, A → aAA | aA | a."

**Quote for the paper:** "The critical innovation is to move grammar analysis to parse-time,
which lets ALL(*) handle any non-left-recursive context-free grammar." (Abstract)

## 5. Verification: Parr & Fisher 2011, "LL(*): The Foundation of the ANTLR Parser Generator" (PLDI'11)

**Metadata CONFIRMED** via Crossref + DBLP conf/pldi/ParrF11: Terence Parr, Kathleen Fisher;
PLDI 2011 proceedings, pages 425–436, ACM, June 2011; DOI 10.1145/1993498.1993548.
Full text obtained: antlr.org author copy (https://www.antlr.org/papers/LL-star-PLDI11.pdf,
marked "DRAFT Accepted to PLDI 2011", saved as llstar.pdf).

```bibtex
@inproceedings{DBLP:conf/pldi/ParrF11,
  author       = {Terence Parr and Kathleen Fisher},
  title        = {LL(*): the foundation of the {ANTLR} parser generator},
  booktitle    = {Proceedings of the 32nd {ACM} {SIGPLAN} Conference on Programming
                  Language Design and Implementation, {PLDI} 2011},
  pages        = {425--436},
  publisher    = {{ACM}},
  year         = {2011},
  doi          = {10.1145/1993498.1993548}
}
```

**Quote for the paper:** "PEGs preclude only the use of left-recursive grammar rules."
(Section 1; author draft). Also useful: "ANTLR accepts all but left-recursive context-free
grammars, so as with GLR or PEG parsing, programmers do not have to contort their grammars
to fit the parsing strategy." (Section 2)

---

## Rigor-bar calibration summary (across the three editor-suggested TOPLAS papers)

Two distinct accepted TOPLAS shapes: (1) Scott et al. 2023 — theory-led, complete formal
development (definitions, lemmas, theorem, appendix proofs) with a scoped single-language
case study and meticulous measurement methodology, explicitly deferring full evaluation;
(2) Jourdan-Pottier 2017 — proof-free engineering paper whose acceptance rests on a real,
hard problem, an unusually clean artifact, and complete candor about what is and is not
established ("possibly correct" in the title). Larchevêque 1995 (proofs outlined in a
15-page "communication") reflects an older bar. Implication for our submission: either give
complete proofs of the core claims (termination, correctness of left-recursion handling,
complexity bounds) with a solid empirical section, or, where we cannot prove, be
Jourdan-Pottier-level explicit about the informal status — TOPLAS clearly rewards candor
over overclaiming. Notably, the editor's three picks are LALR/GLL/LR papers, none PEG-based:
the related-work section should bridge to the CFG-parsing tradition (GLL/GLR/Earley,
incremental LR) rather than staying inside the PEG literature.
