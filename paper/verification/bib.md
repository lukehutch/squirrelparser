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
