# The Squirrel Parser 🐿️

A fast, robust **PEG packrat parser** that handles all forms of left recursion and provides optimal error recovery, all while maintaining **linear-time performance** O(n·|G|). This makes the squirrel parser the fastest and the most robust general purpose error-recovering parser.

## Overview

Traditional PEG parsers struggle with two problems:

1. **Left Recursion**: Rules like `E <- E '+' T / T` cause infinite loops, or require grammar rewriting, or ugly hacks to the parser logic.
2. **Error Recovery**: When parsing fails, recovery is ad-hoc and slow, if the parser supports error recovery at all.

The Squirrel Parser solves both problems in provably optimal ways.

## Quick Start

Isomorphic implementations are provided for four languages:

- **[Dart](dart/)**
- **[Python](python/)**
- **[TypeScript](typescript/)**
- **[Java](java/)**

## The theory

For the full derivation of the algorithm, see [the paper](paper/squirrel_parser.pdf):

> *The Squirrel Parser: A Linear-Time PEG Packrat Parser Capable of Left Recursion and Optimal Error Recovery, Luke A. D. Hutchison, 2026*

## The emoji

Yes, [that's a chipmunk, not a squirrel](https://www.unicode.org/L2/L2017/17442-squirrel-emoji.pdf).