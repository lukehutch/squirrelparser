# Citation verification: PEG/packrat history (for TOPLAS paper)

Verified 2026-07-20. Methods: Crossref API (api.crossref.org), DBLP search API, full-text
PDFs downloaded and read (pdftotext) from bford.info, aclanthology.org, and
archive.computerhistory.org. All quotes below were copied verbatim from text I actually
fetched; locators give printed page and/or section. Working copies of every fetched
PDF/text are in `scratchpad/cites/`.

---

## 1. Ford 2002 (ICFP) — "Packrat Parsing: Simple, Powerful, Lazy, Linear Time"

**Status: VERIFIED-FULLTEXT** (author's PDF, 6 pp., fetched from
https://bford.info/pub/lang/packrat-icfp02.pdf; metadata from
https://api.crossref.org/works/10.1145/581478.581483).

Note: the author's PDF is 6 pages; the ACM proceedings version spans pp. 36-47, so page
locators below use sections of the paper, which are identical in both versions.

**Claim check:** SUPPORTED.
- Packrat parsing = memoizing backtracking recursive descent, linear time: directly stated
  (quotes 1-3).
- Does NOT introduce PEGs: CONFIRMED — the strings "parsing expression grammar" and "PEG"
  appear nowhere in the paper text (checked by grep over the full extracted text). The
  grammar formalism is described only via recursive-descent grammar rules; the theoretical
  antecedents cited are Birman-era "theoretical foundations ... worked out in the 1970s".

**Quotes:**
1. (Abstract) "A packrat parser provides the power and flexibility of top-down parsing
   with backtracking and unlimited lookahead, but nevertheless guarantees linear parse
   time."
2. (Abstract) "in fact converting a backtracking recursive descent parser into a
   linear-time packrat parser often involves only a fairly straightforward structural
   change."
3. (Section 1, Introduction) "by saving all intermediate parsing results as they are
   computed and ensuring that no result is evaluated more than once. The theoretical
   foundations of this algorithm were worked out in the 1970s [3, 4]"

Bonus (Section 3.1, if useful): "One limitation packrat parsing shares with other
top-down schemes is that it does not directly support left recursion."

**BibTeX:**
```bibtex
@inproceedings{ford2002packrat,
  author    = {Ford, Bryan},
  title     = {Packrat Parsing: Simple, Powerful, Lazy, Linear Time (Functional Pearl)},
  booktitle = {Proceedings of the Seventh {ACM} {SIGPLAN} International Conference
               on Functional Programming ({ICFP} '02)},
  year      = {2002},
  pages     = {36--47},
  publisher = {ACM},
  address   = {Pittsburgh, Pennsylvania, USA},
  doi       = {10.1145/581478.581483}
}
```

---

## 2. Ford 2002 (MIT Master's thesis) — "Packrat Parsing: a Practical Linear-Time Algorithm with Backtracking"

**Status: VERIFIED-FULLTEXT** (full 112-page PDF fetched from
https://bford.info/pub/lang/thesis.pdf and read).

Metadata confirmed from the thesis title page: submitted to the MIT Department of
Electrical Engineering and Computer Science on September 3, 2002, for the degree of
Master of Science in Computer Science and Engineering; supervisor M. Frans Kaashoek.

**Claim check:** SUPPORTED.
- Memoizing recursive descent / linear time: quote 1.
- Cannot handle left recursion directly: quotes 2-3 (Sections 2.3.5 and 3.2.1). The
  thesis's prescribed workaround is grammar rewriting: "Fortunately, a left-recursive
  context-free grammar can always be rewritten into an equivalent right-recursive one
  [2]" (Section 3.2.1, p. 40).
- Terminology note: the thesis calls the formalism **TDPL**, not PEG — further support
  that PEGs-as-such date from 2004.
- Bonus finding: the **farthest-failure error heuristic is in this thesis, NOT in the
  POPL 2004 paper** (Section 3.2.4, "Error Handling", pp. 46-49; Ford credits Parsec as
  the inspiration: "The error handling method presented here is inspired by the method
  used in the Parsec combinator library", p. 47). See quote 4.

**Quotes:**
1. (Abstract, p. 3) "Packrat parsing is a novel and practical method for implementing
   linear-time parsers for grammars defined in Top-Down Parsing Language (TDPL)."
2. (Section 2.3.5, p. 25) "In TDPL, while right recursion works in much the same way as
   it does in a CFG, a left-recursive definition is considered erroneous, because its
   interpretation under TDPL rules leads to a degenerate self-reference."
3. (Section 3.2.1, p. 39) "One limitation packrat parsing inherits from TDPL and shares
   with other top-down parsing schemes is that it does not directly support left
   recursion."
4. (Section 3.2.4, p. 48) "a simple heuristic that provides good results in practice is
   simply to prefer information produced at positions farthest to the right in the input
   stream."

**BibTeX:**
```bibtex
@mastersthesis{ford2002thesis,
  author  = {Ford, Bryan},
  title   = {Packrat Parsing: A Practical Linear-Time Algorithm with Backtracking},
  school  = {Massachusetts Institute of Technology},
  address = {Cambridge, MA},
  year    = {2002},
  month   = sep,
  url     = {https://bford.info/pub/lang/thesis.pdf}
}
```

---

## 3. Ford 2004 (POPL) — "Parsing Expression Grammars: A Recognition-Based Syntactic Foundation"

**Status: VERIFIED-FULLTEXT** (author's 12-page PDF fetched from
https://bford.info/pub/lang/peg.pdf; metadata from
https://api.crossref.org/works/10.1145/964001.964011: POPL '04, Venice, pp. 111-122,
January 2004). Page numbers below are mapped from the author PDF's page position onto
the ACM range 111-122 (both are 12 pages); sections are exact.

**Claim checks:**
- **PEGs introduced here (2004, not 2002): SUPPORTED.** This paper defines PEGs
  (Definition in Section 3; abstract, quote 1). Combined with the grep evidence from
  works 1-2 (no "PEG"/"parsing expression grammar" in either 2002 work; thesis uses
  "TDPL"), the term and formalism "PEG" first appear in this 2004 paper.
- **Ordered choice makes PEGs unambiguous: SUPPORTED** (quotes 1-2; Section 2.3
  "Priorities, Not Ambiguities", p. 114).
- **Open question whether PEGs can express all CFLs: SUPPORTED** (quote 4, Section 5,
  p. 121).
- **PEGs cannot handle left recursion ("degenerate loop"): SUPPORTED** (quote 3,
  Section 2.4, p. 114). The well-formedness condition of Section 4.5 (p. ~117-118)
  statically "rejects grammars with directly or mutually left-recursive rules, such as
  'A <- A a / a', which could prevent the grammar from handling any input string."
- **Error reporting / farthest-failure: NOT SUPPORTED by this paper.** The POPL 2004
  paper says nothing about error reporting or failure heuristics; the only occurrence of
  "error" in the body is in the acknowledgments ("pointing out several errors in the
  original draft"). If the paper cites a farthest-failure heuristic, cite Ford's 2002
  thesis Section 3.2.4 instead (see work 2, quote 4).

**Quotes:**
1. (Abstract, p. 111) "Parsing Expression Grammars (PEGs) provide an alternative,
   recognition-based formal foundation for describing machine-oriented syntax, which
   solves the ambiguity problem by not introducing ambiguity in the first place."
2. (Abstract, p. 111) "Where CFGs express nondeterministic choice between alternatives,
   PEGs instead use prioritized choice."
3. (Section 2.4, p. 114) "Both left and right recursion are permissible in CFGs, but as
   with top-down parsing in general, left recursion is unavailable in PEGs because it
   represents a degenerate loop." — continuing: "the PEG rule 'A <- A a / a' is
   degenerate because it indicates that in order to recognize nonterminal A, a parser
   must first recognize nonterminal A. . . This restriction applies not only to direct
   left recursion as in this example, but also to indirect or mutual left recursion
   involving several nonterminals."
4. (Section 5, p. 121) "It is not even proven yet that CFLs exist that cannot be
   recognized by a PEG, though recent work in lower bounds on the complexity of general
   CFG parsing [14] and matrix product [23] shows at least that general CFG parsing is
   inherently super-linear."
5. (Section 1, p. 112 — useful for the Birman lineage) "originally named TS ("TMG
   recognition scheme") and gTS ("generalized TS") by Alexander Birman [4, 5], in
   reference to an early syntax-directed compiler-compiler. These systems were later
   called TDPL ("Top-Down Parsing Language") and GTDPL ("Generalized TDPL") respectively
   by Aho and Ullman [3]."

**BibTeX:**
```bibtex
@inproceedings{ford2004peg,
  author    = {Ford, Bryan},
  title     = {Parsing Expression Grammars: A Recognition-Based Syntactic Foundation},
  booktitle = {Proceedings of the 31st {ACM} {SIGPLAN}-{SIGACT} Symposium on
               Principles of Programming Languages ({POPL} '04)},
  year      = {2004},
  month     = jan,
  pages     = {111--122},
  publisher = {ACM},
  address   = {Venice, Italy},
  doi       = {10.1145/964001.964011}
}
```

---

## 4. Birman & Ullman 1973 — "Parsing Algorithms with Backtrack" (+ Birman 1970 PhD thesis)

### 4a. Journal article

**Status: METADATA-ONLY** (Crossref record
https://api.crossref.org/works/10.1016/S0019-9958(73)90851-6 and DBLP record
journals/iandc/BirmanU73 both fetched and read). I could NOT fetch the article text:
ScienceDirect returns a Cloudflare bot challenge (403) for both the landing page and the
signed PDF link, and Unpaywall lists no OA mirror. No quotes are given for the journal
version — do not quote it without ACM/Elsevier access.

**DISCREPANCY: the title is "Parsing Algorithms with Backtrack", NOT "Parsing Algorithms
with Backtracking"** (confirmed by both Crossref and DBLP, and by the Google-indexed
first-page header "INFORMATION AND CONTROL 23, 1-34 (1973) Parsing Algorithms with
Backtrack*"). Fix the title in the paper's .bib if it currently says "Backtracking".
Metadata: Information and Control 23(1):1-34, August 1973, Elsevier,
DOI 10.1016/S0019-9958(73)90851-6. DBLP also records an earlier conference version:
IEEE SWAT (11th Annual Symposium on Switching and Automata Theory) 1970, pp. 153-174
(conf/focs/BirmanU70) — useful if you want the 1970 date in print.

### 4b. Birman 1970 PhD thesis

**Status: VERIFIED-FULLTEXT** — a scan of the complete dissertation is hosted by Ford at
https://bford.info/packrat/ref/birman70tmg.pdf (fetched; title page and Chapters I-II
read). Title page (verbatim, modulo OCR): "THE TMG RECOGNITION SCHEMA / Alexander Birman
/ A DISSERTATION PRESENTED TO THE FACULTY OF PRINCETON UNIVERSITY IN CANDIDACY FOR THE
DEGREE OF DOCTOR OF PHILOSOPHY / RECOMMENDED FOR ACCEPTANCE BY THE DEPARTMENT OF
ELECTRICAL ENGINEERING / February, 1970". Acknowledgments name Jeffrey D. Ullman as
thesis advisor. Ford's POPL04 reference [4] cites it identically.

**Claim check:** SUPPORTED. Top-down backtracking recognition schemes (the TMG
recognition scheme, later TDPL) are fully formalized in a February 1970 dissertation and
a 1973 journal paper — 34 and 31 years before POPL 2004. Ford himself says PEGs "are
reducible to two minimal recognition schemas developed around 1970, TS/TDPL and
gTS/GTDPL" (POPL04 abstract).

**Quotes (from the 1970 thesis scan; scan is a typescript, OCR lightly corrected for
spacing only):**
1. (Ch. I, p. 1) "TMG is a compiler writing system reported by McClure in [1]."
2. (Ch. I, p. 1) "The formalization of the syntactic analysis schema used in TMG and the
   investigation of its properties form the scope of this work."
3. (Ch. I, pp. 1-2) "Chapter V discusses time complexity: it is shown that the languages
   'recognized' by the TS, the TSL, can be recognized in linear time by a given
   algorithm." — i.e., the linear-time (tabular) recognition result that packrat parsing
   revives is already in the 1970 thesis.

**BibTeX:**
```bibtex
@article{birman1973parsing,
  author  = {Birman, Alexander and Ullman, Jeffrey D.},
  title   = {Parsing Algorithms with Backtrack},
  journal = {Information and Control},
  volume  = {23},
  number  = {1},
  pages   = {1--34},
  year    = {1973},
  month   = aug,
  doi     = {10.1016/S0019-9958(73)90851-6}
}

@phdthesis{birman1970tmg,
  author  = {Birman, Alexander},
  title   = {The {TMG} Recognition Schema},
  school  = {Princeton University, Department of Electrical Engineering},
  address = {Princeton, NJ},
  year    = {1970},
  month   = feb,
  note    = {Scan available at \url{https://bford.info/packrat/ref/birman70tmg.pdf}}
}
```

---

## 5. Norvig 1991 — "Techniques for Automatic Memoization with Applications to Context-Free Parsing"

**Status: VERIFIED-FULLTEXT** (full PDF fetched from https://aclanthology.org/J91-1004.pdf
and read). Metadata: Computational Linguistics 17(1):91-98, 1991 (a "Technical
Correspondence" item; affiliation University of California, Berkeley).

**Claim check:** SUPPORTED, with one nuance worth knowing: the naively memoized parser is
O(n^4) because hashing on the token-list argument is O(n); Norvig then obtains O(n^3)
with a multi-level eql hash table — "Finally, we can get an O(n^3) parser by saying:
(memoize 'parse :getter #'get-multi-hash :putter #'put-multi-hash)" (p. 95). So
"Earley-like efficiency" is achieved, but only after the hashing refinement.

**Quotes:**
1. (Abstract, p. 91) "It is shown that a process similar to Earley's algorithm can be
   generated by a simple top-down backtracking parser, when augmented by automatic
   memoization."
2. (Abstract, p. 91) "The memoized parser has the same complexity as Earley's algorithm,
   but parses constituents in a different order."
3. (Section 2, p. 94) "This paper's contribution is a concrete demonstration of just how
   direct the correspondence is between the simple and the efficient algorithm. We
   present a simple parser which, when memoized, performs the same calculations as
   Earley's algorithm."

**BibTeX:**
```bibtex
@article{norvig1991memoization,
  author  = {Norvig, Peter},
  title   = {Techniques for Automatic Memoization with Applications to
             Context-Free Parsing},
  journal = {Computational Linguistics},
  volume  = {17},
  number  = {1},
  pages   = {91--98},
  year    = {1991},
  url     = {https://aclanthology.org/J91-1004/}
}
```

---

## 6a. Irons 1961 — "A Syntax Directed Compiler for ALGOL 60"

**Status: METADATA-ONLY** (Crossref record
https://api.crossref.org/works/10.1145/366062.366083 fetched; DBLP confirms). ACM DL is
bot-blocked (403), so I could not read the text; no quotes. Metadata confirmed:
Edgar T. Irons (Princeton Univ.), Communications of the ACM 4(1):51-55, January 1961,
DOI 10.1145/366062.366083. DBLP also records a 1983 reprint: CACM 26(1):14-16
(DOI 10.1145/357980.357986) — do not confuse the two DOIs.

**Claim check:** metadata is consistent with "1961, ALGOL 60, syntax-directed
top-down compiler", but I could not verify at text level that Irons's parser is
recursive/top-down in the modern recursive-descent sense — treat the "earliest
recursive/top-down parsing of ALGOL 60" attribution as resting on secondary literature
unless the text is checked. (Irons's is conventionally described as the first
*syntax-directed* compiler; the explicit *recursive-procedure* method is what Lucas 1961
spells out — see 6b, verified below.)

**BibTeX:**
```bibtex
@article{irons1961syntax,
  author  = {Irons, Edgar T.},
  title   = {A Syntax Directed Compiler for {ALGOL} 60},
  journal = {Communications of the ACM},
  volume  = {4},
  number  = {1},
  pages   = {51--55},
  year    = {1961},
  month   = jan,
  doi     = {10.1145/366062.366083}
}
```

## 6b. Lucas 1961 — "The Structure of Formula-Translators"

**Status: VERIFIED-FULLTEXT (front matter + p. 1 read from page scans)** at the Computer
History Museum archive:
https://archive.computerhistory.org/resources/text/algol/algol_bulletin/AS16/AS16.HTM
(page images AS16P0.GIF ... AS16P27.GIF; I read pages 0 and 1).

Metadata confirmed from the scanned front page: "ALGOL BULLETIN SUPPLEMENT No. 16 / The
Structure of Formula-Translators (Theoretical Investigation of Translators) / by
P. LUCAS / September 1961"; author footnote "MAILUFTERL, Vienna IV, Gusshausstrasse 25".
The front page also states, verbatim: "This Algol Bulletin Supplement is a reprint of a
part of the Final Report DA-91-591-EUC-1430 'An Extension of the Algorithmic Language
ALGOL' ... The same text has appeared also in German in the August 1961 issue of
'Elektronische Rechenanlagen' (Munich)." The CHM index lists it as pp. 0-27.

**Quote:**
1. (Section 1.10, p. 1.1-1) "The following paper is intended to show a method how to
   derive the structure of a translator on the basis of the syntactic definitions of the
   programming language."
2. (Section 1.101, p. 1.1-1) "This paper was written in the course of designing a
   translator for the algorithmic formula language ALGOL 60 [2]."

**Claim check:** SUPPORTED at the metadata/provenance level (September 1961 English
reprint; German original August 1961), and the read pages confirm it derives translator
structure directly from the syntax definitions of ALGOL 60. I did not read the middle
pages where the recursive-procedure construction itself appears; if a verbatim quote of
the recursive mechanism is needed, pages 2-27 are available at the same URL.

**BibTeX:**
```bibtex
@article{lucas1961structure,
  author  = {Lucas, Peter},
  title   = {The Structure of Formula-Translators},
  journal = {{ALGOL} Bulletin},
  volume  = {Supplement 16},
  pages   = {1--27},
  year    = {1961},
  month   = sep,
  note    = {English reprint of part of Final Report DA-91-591-EUC-1430; German
             version in Elektronische Rechenanlagen 3 (August 1961). Scans:
             \url{https://archive.computerhistory.org/resources/text/algol/algol_bulletin/AS16/AS16.HTM}}
}
```

---

## Summary of discrepancies / cautions

1. **Birman & Ullman title**: "Parsing Algorithms with **Backtrack**", not
   "Backtracking". (Crossref + DBLP.)
2. **Farthest-failure heuristic is NOT in POPL 2004** — it is in Ford's 2002 thesis,
   Section 3.2.4 (pp. 46-49), credited to Parsec. Cite the thesis for that claim.
3. **Irons 1961**: metadata-only; the "recursive descent" characterization is not
   text-verified here.
4. **Birman & Ullman 1973 journal text unreachable** (Cloudflare); the 1970 thesis scan
   on bford.info fully substantiates the "predates PEG by three decades" claim instead.
5. Ford ICFP02 author PDF paginates differently from the ACM version (pp. 36-47); cite
   ICFP02 quotes by section.
