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
