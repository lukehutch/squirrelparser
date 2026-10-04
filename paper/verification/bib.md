# Citation Verification Record: squirrel_parser.tex

Verified 2026-07-20. Full per-key records, with verbatim quotes, locators, fetched-source
URLs, and discrepancy notes, are in the four files in this directory; this index maps every
BibTeX key cited by `squirrel_parser.tex` to its record and status.

Status legend: FULLTEXT = quotes copied from fetched primary text; ABSTRACT = verified
against publisher abstract only; METADATA = bibliographic record verified (Crossref/DBLP)
but text not reachable.

| Key | Work | Status | Record |
|---|---|---|---|
| irons1961syntax | Irons 1961, CACM 4(1) | METADATA (ACM DL bot-blocked; do not confuse with 1983 reprint DOI) | cites_history.md §6a |
| lucas1961structure | Lucas 1961, ALGOL Bulletin Suppl. 16 | FULLTEXT (CHM scans, front matter + p.1) | cites_history.md §6b |
| kegler2023parsing | Kegler, Parsing: A Timeline (website) | METADATA (site live) | n/a (website) |
| birman1970 | Birman 1970 Princeton PhD thesis | FULLTEXT (scan at bford.info) | cites_history.md §4b |
| birman1973 | Birman & Ullman 1973, Inf. & Control | METADATA (title corrected to "Backtrack") | cites_history.md §4a |
| norvig1991 | Norvig 1991, Computational Linguistics | FULLTEXT (aclanthology) | cites_history.md §5 |
| ford2002 | Ford ICFP 2002 | FULLTEXT (bford.info; confirms no "PEG" in text) | cites_history.md §1 |
| ford2002b | Ford 2002 MIT thesis | FULLTEXT (112pp read; farthest-failure is here, §3.2.4) | cites_history.md §2 |
| ford2004 | Ford POPL 2004 | FULLTEXT (PEG introduced here; degenerate-loop quote) | cites_history.md §3 |
| warth2008 | Warth et al. PEPM 2008 | FULLTEXT (UCLA copy; super-linear admission quoted) | cites_leftrec.md §1 |
| tratt2010 | Tratt 2010 EIS-10-01 | FULLTEXT ("violates a fundamental aspect of PEGs" quote) | cites_leftrec.md §2 |
| medeiros2014 | Medeiros et al. SCP 2014 | FULLTEXT (arXiv 1207.0443v3; states NO asymptotic bound) | cites_leftrec.md §3 |
| frost2008 | Frost et al. PADL 2008 | FULLTEXT (author preprint via Wayback) | cites_leftrec.md §4 |
| parr2014 | Parr et al. OOPSLA 2014 | FULLTEXT (direct-LR-only + O(n^4) quotes) | cites_editor.md §4 |
| pegged | Pegged Left-Recursion wiki | FULLTEXT (raw wiki markdown; "interlocking cycles") | cites_leftrec.md §7 |
| hutchison2020 | Hutchison 2020 pika (arXiv) | FULLTEXT ("rules of interest"; ~100x Parboiled2 quote) | cites_leftrec.md §6 |
| damerau1964 | Damerau 1964, CACM | FULLTEXT ("over 80 percent" statistic quoted, p.171) | cites_recovery.md §9 |
| levenshtein1966 | Levenshtein 1966, Sov. Phys. Dokl. | FULLTEXT (scan; 1965 Russian original confirmed) | cites_recovery.md §8 |
| wagner1974 | Wagner & Fischer 1974, JACM | FULLTEXT (Algorithm X + traceback Y quoted) | cites_recovery.md §10 |
| dijkstra1959 | Dijkstra 1959, Numer. Math. | FULLTEXT (CWI scan) | cites_recovery.md §11 |
| aho1972 | Aho & Peterson 1972, SIAM J. Comput. | ABSTRACT (body paywalled; "error productions" phrasing supported via Lyon 1974 quote) | cites_recovery.md §1 |
| lyon1974 | Lyon 1974, CACM | FULLTEXT (subtitle kept; O(n^3) time / O(n^2) space) | cites_recovery.md §2 |
| burke1987 | Burke & Fisher 1987, TOPLAS | FULLTEXT (parse action deferral, parse check quotes) | cites_recovery.md §3 |
| swierstra1996 | Swierstra & Duponcheel 1996, LNCS 1129 | FULLTEXT (Tufts author archive) | cites_recovery.md §7 |
| dejonge2012 | de Jonge et al. 2012, TOPLAS 34(4) | FULLTEXT (TUD-SERG-2012-021 preprint) | cites_recovery.md §4 |
| medeiros2018 | Medeiros & Mascarenhas SAC 2018 | FULLTEXT (arXiv 1806.11150) | cites_recovery.md §6 |
| medeiros2020 | de Medeiros et al. SCP 2020 | FULLTEXT (arXiv 1905.02145; DOI corrected from a wrong SPE DOI) | cites_recovery.md §6 |
| diekmann2020 | Diekmann & Tratt ECOOP 2020 | FULLTEXT (Dagstuhl OA PDF; "before the error point" is our characterization, not their sentence) | cites_recovery.md §5 |
| treesitter | tree-sitter repo | METADATA + docs quotes (GLR, error robustness) | cites_recovery.md §12 |
| larcheveque1995 | Larcheveque 1995, TOPLAS 17(1) | METADATA + abstract (body paywalled) | cites_editor.md §3 |
| dubroy2017 | Dubroy & Warth SLE 2017 | METADATA (Crossref: title/authors/pages/DOI confirmed in-session) | this file |
| fried2021kdyck | Fried et al. 2021, arXiv 2111.02336 (LESSONS round 27, not cited by the paper) | FULLTEXT (arXiv LaTeX source) | cites_recovery.md §13 |

## Claim-mapping notes (discrepancies resolved during writing)

- The paper credits PEGs to Ford 2004 (not 2002) and the farthest-failure heuristic to the
  2002 thesis; both confirmed by full-text grep/reading (cites_history.md).
- Warth et al. incorrectness/surprising-associativity findings are attributed to Tratt 2010
  and Medeiros et al. 2014 (with quotes), never to Warth et al. themselves.
- Medeiros et al. 2014 state no asymptotic complexity bound; the paper only says their
  semantics "re-evaluates the rule under an explicit increasing bound" and shares the
  quadratic worst case "in the same pattern" (an analysis, not an attributed claim).
- Lyon 1974 is cited as "a practical variant" of least-errors parsing (cubic time); the
  quadratic figure is space only and does not appear in the paper.
- The Medeiros 2020 recovery follow-up citation was corrected from a wrong Wiley SPE DOI to
  Science of Computer Programming 187:102373, DOI 10.1016/j.scico.2019.102373.
- "Cannot repair an error whose edit lies before the failure point" (re CPCT+ etc.) is
  presented as our structural characterization, not as a quotation.

## Empirical-number verification

Every measured number quoted in the paper (mutation counts, cost-1 totals, structural
restoration, parse counts, work-per-character tables, adversarial work ratios, semantics
example results) is re-checked by `verify_paper_numbers.dart` in this directory; see
`verify.py`. Timing figures (ms/s) are environment-dependent (AMD Ryzen 9 3950X,
Dart 3.12.2, single thread, 2026-07-20) and are recorded but not asserted.

## Alur2010expressiveness

```bibtex
@inproceedings{Alur2010expressiveness,
  doi = {10.4230/LIPIcs.FSTTCS.2010.1},
  url = {https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.FSTTCS.2010.1},
  author = {Alur, Rajeev and Černý, Pavol},
  keywords = {streaming string transducer, list processing, heap manipulation, monadic second-order transduction},
  language = {en},
  title = {Expressiveness of streaming string transducers},
  journal = {LIPIcs, Volume 8, FSTTCS 2010},
  volume = {8},
  pages = {1--12},
  publisher = {Schloss Dagstuhl – Leibniz-Zentrum für Informatik},
  year = {2010},
  copyright = {Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported license}
}
```

- **Verified authors**: Alur, Rajeev and Černý, Pavol
- **Verified title**: Expressiveness of streaming string transducers
- **Journal**: LIPIcs, Volume 8, FSTTCS 2010 8 pp. 1--12 (2010)
- **DOI**: 10.4230/lipics.fsttcs.2010.1
- **arXiv**: —
- **Metadata cross-checked against**: DataCite
- **Source URLs**:
  - `https://doi.org/10.4230/lipics.fsttcs.2010.1` — metadata (DataCite)
  - `https://scholar.google.com/scholar?hl=en&as_epq=Expressiveness+of+streaming+string+transducers&as_occt=title` — metadata (Scholar (no usable record))
  - `https://content.openalex.org/works/W1529428897.pdf` — pdf → `Alur2010expressiveness.pdf`
  - `api.core.ac.uk work 19088957` — text at CORE, located but not fetched, fullText field, 46,575 chars — already extracted
  - `https://content.openalex.org/works/W1529428897.grobid-xml` — xml at OpenAlex content, located but not fetched, GROBID TEI XML, $0.01/file
  - `https://repository.upenn.edu/handle/20.500.14332/6848` — html at OpenAlex, located but not fetched, ScholarlyCommons (University of Pennsylvania) — identity unconfirmed
  - `https://repository.upenn.edu/cis_papers/776` — html at OpenAlex, located but not fetched, ScholarlyCommons (University of Pennsylvania) — identity unconfirmed
  - `https://doi.org/10.4230/lipics.fsttcs.2010.1` — html at OpenAlex, located but not fetched, Leibniz international proceedings in informatics
  - `https://core.ac.uk/download/62915774.pdf` — pdf at CORE, located but not fetched, downloadUrl — identity unconfirmed
  - `https://drops.dagstuhl.de/storage/00lipics/lipics-vol008-fsttcs2010/LIPIcs.FSTTCS.2010.1/LIPIcs.FSTTCS.2010.1.pdf` — pdf at OpenAlex, located but not fetched, DROPS (Schloss Dagstuhl – Leibniz Center for Informatics) — identity unconfirmed
- **Abstract** (OpenAlex abstract_inverted_index):

  Streaming string transducers define (partial) functions from input strings to output
  strings. A streaming string transducer makes a single pass through the input string
  and uses a finite set of variables that range over strings from the output alphabet.
  At every step, the transducer processes an input symbol, and updates all the
  variables in parallel using assignments whose right-hand-sides are concatenations of
  output symbols and variables with the restriction that a variable can be used at most
  once in a right-hand-side expression. It has been shown that streaming string
  transducers operating on strings over infinite data domains are of interest in
  algorithmic verification of list-processing programs, as they lead to Pspace decision
  procedures for checking pre/postconditions and for checking semantic equivalence, for
  a well-defined class of heap-manipulating programs. In order to understand the
  theoretical expressiveness of streaming transducers, we focus on streaming
  transducers processing strings over finite alphabets, given the existence of a robust
  and well-studied class of ``regular'' transductions for this case. Such regular
  transductions can be defined either by two-way deterministic finite-state
  transducers, or using a logical MSO-based characterization. Our main result is that
  the expressiveness of streaming string transducers coincides exactly with this class
  of regular transductions.

- **Justification**: Defines streaming string transducers: a single pass that keeps output strings in variables updated by concatenations. Round 28 (pd51, pd52) kept tree forests in per-state registers in this style; LESSONS only, not cited by the paper.
- **Claims supported**:
  - Claim: A streaming string transducer keeps a finite set of string variables updated in parallel by concatenation at each input symbol
    Quote: "It uses a finite set of variables that range over strings from the output alphabet. At every step, the transducer processes an input symbol, and updates all the variables in parallel using assignments whose right-hand-sides are concatenations of output symbols and variables" (pdftotext lines 46-49)
- **Status**: TODO — VERIFIED / DISCREPANCY / UNSUPPORTED
- **Local copies**: `source/Alur2010expressiveness/`
  - `Alur2010expressiveness.pdf` — pdf, 492,344 bytes, sha256 ad77246c68f0
- **Indexes with no record**: Crossref, INSPIRE-HEP, Scholar
- **Notes**: —

## Chang2015hardness

```bibtex
@misc{Chang2015hardness,
  doi = {10.48550/arXiv.1511.04731},
  url = {https://arxiv.org/abs/1511.04731},
  author = {Chang, Yi-Jun},
  keywords = {Computational Complexity (cs.CC), Data Structures and Algorithms (cs.DS), FOS: Computer and information sciences, FOS: Computer and information sciences},
  title = {Hardness of {RNA} Folding Problem with Four Symbols},
  publisher = {arXiv},
  year = {2015},
  copyright = {arXiv.org perpetual, non-exclusive license}
}
```

- **Verified authors**: Chang, Yi-Jun
- **Verified title**: Hardness of {RNA} Folding Problem with Four Symbols
- **Journal**: — (2015)
- **DOI**: 10.48550/arXiv.1511.04731
- **arXiv**: 1511.04731
- **Metadata cross-checked against**: DataCite
- **Source URLs**:
  - `https://doi.org/10.48550/arXiv.1511.04731` — metadata (DataCite)
  - `https://scholar.google.com/scholar?hl=en&as_epq=Hardness+of+RNA+Folding+Problem+with+Four+Symbols&as_occt=title` — metadata (Scholar (no usable record))
  - `https://arxiv.org/src/1511.04731` — arxiv-src-payload → `Chang2015hardness-arxiv-src.tar.gz`
  - `https://arxiv.org/src/1511.04731` — latex → `latex/`
  - `/papers/arx_1511.04731/content.lines` — content.lines → `content.lines`
  - `https://arxiv.org/pdf/1511.04731` — pdf → `Chang2015hardness.pdf`
  - `https://doi.org/10.48550/arxiv.1511.04731` — html at OpenAlex, located but not fetched, arXiv (Cornell University)
  - `https://arxiv.org/html/1511.04731` — html at arXiv, located but not fetched, LaTeXML HTML, converted from the submitted TeX
- **Abstract** (paperclip meta.json):

  An RNA sequence is a string composed of four types of nucleotides, $A, C, G$, and
  $U$. The goal of the RNA folding problem is to find a maximum cardinality set of
  crossing-free pairs of the form $\{A,U\}$ or $\{C,G\}$ in a given RNA sequence. The
  problem is central in bioinformatics and has received much attention over the years.
  Abboud, Backurs, and Williams (FOCS 2015) demonstrated a conditional lower bound for
  a generalized version of the RNA folding problem based on a conjectured hardness of
  the $k$-clique problem. Their lower bound requires the RNA sequence to have at least
  36 types of symbols, making the result not applicable to the RNA folding problem in
  real life (i.e., alphabet size 4). In this paper, we present an improved lower bound
  that works for the alphabet size 4 case. We also investigate the Dyck edit distance
  problem, which is a string problem closely related to RNA folding. We demonstrate a
  reduction from RNA folding to Dyck edit distance with alphabet size 10. This leads to
  a much simpler proof of the conditional lower bound for Dyck edit distance problem
  given by Abboud, Backurs, and Williams (FOCS 2015), and lowers the alphabet size
  requirement.

- **Justification**: Conditional lower bound: exact Dyck edit distance (alphabet 10) has no truly subcubic combinatorial algorithm unless k-clique improves. Exact least-cost PEG repair contains it, so a cubic worst case in the number of bracket errors is expected for any exact engine (LESSONS round 29; not cited by the paper).
- **Claims supported**:
  - Claim: Dyck edit distance on alphabet size 10 is at least as hard as RNA folding, which has a k-clique-based conditional lower bound
    Quote: "If the Dyck edit distance problem on sequences of length $n$ with alphabet size 10  can be solved in $T(n)$ time, then $3k$-clique on graphs with $|V|=n$ can be solved in $T\left( O(n^{k + 1} \log n)\right)$ time." (paper.tex#L159)
    Quote: "Therefore, an ${O}(n^{3- \epsilon})$-time combinatorial algorithm for RNA folding would imply a breakthrough for combinatorial algorithms for $k$-clique." (paper.tex#L123)
- **Status**: TODO — VERIFIED / DISCREPANCY / UNSUPPORTED
- **Local copies**: `source/Chang2015hardness/`
  - `Chang2015hardness-arxiv-src.tar.gz` — arxiv-src-payload, 625,737 bytes, sha256 303626365391
  - `latex/` — latex, 717,193 bytes
  - `content.lines` — content.lines, 82,014 bytes, sha256 55ac87e65e2a
  - `Chang2015hardness.pdf` — pdf, 1,148,673 bytes, sha256 4a17346da995
- **Indexes with no record**: Crossref, INSPIRE-HEP, Scholar, arXiv
- **Notes**: —
