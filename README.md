# q-test

A kdb+/q testing framework built by studying four existing ones —
[`kdb/qunit`](../kdb/qunit) (timestored's QUnit), [`q-unit`](../q-unit)
(jasraj's q-unit/qamcrest), [`qspec`](../qspec) (nugend's rspec-inspired
DSL), and [`resq`](../resq) (a qspec-compatible superset) — plus
[`q-desc`](../q-desc)'s `testFramework`, which generates fuzz test cases
from a function's declared signature. q-test keeps what those frameworks
each do best and combines it in one small, dependency-free engine:

- **Two test-writing styles, one engine.** Write `test*`-prefixed functions
  in a namespace (qunit's zero-boilerplate naming convention — no
  registration call needed beyond loading the file) *or* write
  `describe`/`should` blocks (qspec/resq's BDD DSL). Both run through the
  exact same primitive (`.qt.i.runOne` in `lib/runner.q`), so pass/fail/
  error/timing/memory are computed identically and land in one shared
  result schema no matter which style produced them. None of the source
  frameworks share a single execution core across two DSLs like this.
- **Auto-restoring mocks**, ported from qunit's `mock`/`reset` idea:
  `.qt.mock[name;val]` remembers the previous value (or the fact that it
  didn't exist), `.qt.restore[]` puts everything back — including correctly
  handling that q can't truly delete a bare top-level name once created
  (it clears to `::` instead of fully removing it, and says so honestly).
- **Property-based testing with automatic shrinking** (`.qt.gen.forAll`),
  inspired by q-desc's fuzz-from-signature idea and resq's `holds`, but
  simpler than either: no `//@param` annotation file to keep in sync
  (q-desc) and no separate generator protocol to implement (resq) —
  generators are just plain composable values (`.qt.gen.int[0;100]`, etc.)
  and a failing property is shrunk toward a minimal counterexample with a
  replay seed printed for reproduction.
- **A pollution guard**, a lighter version of resq's namespace-sandboxing:
  snapshot root's direct children before/after a namespace or `describe`
  block runs, and warn (not silently ignore) about anything new left
  behind — nudging you toward `.qt.mock`/`.qt.restore` instead of bare
  globals, without resq's full per-file sandbox machinery.
- **Pure q, zero shell dependency.** `resq` requires bash plus `mktemp`,
  `timeout`, etc.; q-unit's launcher is a two-stage bash bootloader. q-test's
  CLI (`bin/qtest.q`) is itself a q script — `q bin/qtest.q <path>` runs
  identically on Windows, Linux, and macOS.
- **JUnit XML output** for CI, the one piece of q-unit's TeamCity ambitions
  and resq's reporter stack that most CI systems actually need.
- **Scaffold a test file straight from a source file**, `q bin/qtest.q
  generate src/math.q` writes `tests/math_test.q` with one property-based
  smoke test per function it finds — no `//@param` annotation step first,
  unlike q-desc's `testFramework` (which this borrows the core idea from):
  arity is read directly off the loaded function, and every generated case
  is clearly marked as a starting point to refine, not a finished test.

None of this is trying to out-feature resq, which is already a large,
comprehensive superset of qspec — the goal here was a small (~800 lines
across 8 files), self-contained engine that keeps the two things worth
keeping from every framework surveyed and drops the rest.

## Layout

```
lib/assert.q     assertEquals / assertTrue / assertThat / assertError / ...
lib/mock.q       .qt.mock / .qt.restore
lib/discover.q   naming-convention scan (test*/setUp*/tearDown*/beforeAll*/afterAll*)
lib/gen.q        .qt.gen.* generators + .qt.gen.forAll property testing
lib/runner.q     shared execution primitive + convention-style orchestration
lib/dsl.q        describe/should BDD DSL, built on the same primitive
lib/report.q     console summary + JUnit XML
lib/scaffold.q   generates a *_test.q from a plain source file
bin/qtest.q      CLI: q bin/qtest.q <path> [-junit <file>] [-strict]
                      q bin/qtest.q generate <srcFile.q> [-outDir <dir>]
examples/        a worked example of each style
tests/           q-test's own test suite, written using q-test itself
```

## Quick start

```
q bin/qtest.q examples/
```

```
[q-test] loading 2 test file(s) from examples
  examples/math_test.q
  examples/stack_spec.q

q-test summary: 9 total  8 passed  0 failed  0 errored  1 skipped  0 pending  (0ms)
```

Flags: `-junit <file>` writes a JUnit XML report; `-strict` makes an empty
result set (no test files matched, or every test skipped) exit non-zero
instead of the default 0.

Discovery loads every file under `<path>` matching `*_test.q`, `test_*.q`,
or `*_spec.q` (top level of that directory only — no recursion yet).

## Writing tests, convention style

Functions named `test*` in a namespace are found and run automatically;
`setUp*`/`tearDown*` run around every test, `beforeAll*`/`afterAll*` run once
for the namespace. A `parameters` function, if present, reruns the whole
namespace once per value it returns, with that value bound to `parameter`.

```q
system "l math.q";
\d .mathTest

testAdd:{.qt.assertEquals[.math.add[2;2];4;"2+2=4"]};
testAddSymbolErrors:{.qt.assertError[.math.add[2;];`two;"cannot add a symbol"]};

\d .
.qt.register[`.mathTest];
```

`.qt.register` marks the namespace to run when the CLI calls
`.qt.runAll[]`; call `.qt.runNamespace \`.mathTest` directly for interactive
use instead.

## Writing tests, BDD style

```q
.qt.describe["Stack"]{
  .qt.before{`.stack.s set ()};

  .qt.should["push adds an element"]{
    .stack.s:.stack.push[.stack.s;1];
    (count .stack.s) ~ 1
   };

  .qt.skip["not implemented yet"]{1b};
  .qt.pending["someday"];
 };
```

`describe`'s block runs once to *collect* `should`/`skip`/`pending`/
`before`/`after`/`beforeAll`/`afterAll` — the test bodies themselves don't
run during collection, so hooks apply correctly regardless of where in the
block they're declared. `describe` runs (and records results) immediately
when the file loads; there's no separate registration step. (It's
`describe`, not `desc` — `desc` is a reserved q keyword, descending
sort/attribute, and can't be assigned at all, even namespaced.)

A `should` block's own return value is what's checked as the assertion
result *only* when it's the literal boolean the block ends on — use
`.qt.assertEquals`/`.qt.assertTrue`/etc. inside the block for anything more
specific, exactly as in the convention style; both styles share the same
assertion library.

## Mocking

```q
.qt.mock[`.a.b;22];       / remembers .a.b's old value
.qt.mock[`.a.f;{13}];     / remembers .a.f's old value
... run code that depends on the mocked values ...
.qt.restore[];            / puts everything back exactly as it was
```

Call `.qt.restore[]` from `tearDown*`/`.qt.after`/`.qt.afterAll` so one
test's mocks never leak into the next.

## Property-based testing

```q
testAddCommutes:{
  .qt.gen.forAll[(.qt.gen.int[-1000;1000];.qt.gen.int[-1000;1000]);
    {[a;b] .math.add[a;b] = .math.add[b;a]};
    "add is commutative"]
 };
```

Built-in generators: `gen.int[lo;hi]`, `gen.float[lo;hi]`, `gen.bool`,
`gen.sym[pool]`, `gen.str[maxLen]`, `gen.oneOf[choices]`,
`gen.listOf[gen;maxLen]`. On failure, `forAll` shrinks the counterexample
(halving numbers toward 0, dropping list elements) before reporting it,
and prints a `system "S <seed>"` line to replay the exact failing run.
A single generator doesn't need to be wrapped in a list —
`.qt.gen.forAll[.qt.gen.int[0;100];...]` and
`.qt.gen.forAll[(.qt.gen.int[0;100]);...]` both work; `forAll` detects the
unwrapped case itself.

## Generating a test file from a source file

```
q bin/qtest.q generate examples/math.q
```

```
[q-test] wrote tests/math_test.q (3 test case(s) generated)
```

For every function `lib/scaffold.q` finds in the source file, it writes one
`.qt.gen.forAll` smoke test — generic `.qt.gen.int[-100;100]` generators
per argument, arity read directly off the loaded function, no annotation
step required. The result is a normal, editable `*_test.q`: narrow the
generators to each argument's real domain, or replace a case outright, the
same as any hand-written test. It found the function's own namespace by
scanning for the file's `\d .foo` line; a file with no such line is scanned
by diffing root's globals before/after loading instead. `-outDir <dir>`
changes where the file is written (default `tests`); functions of arity
over 8, or anything that isn't a plain lambda (a projection, a composed
function), are skipped and listed in the summary rather than guessed at.

## What's deliberately not here

Coverage instrumentation, distributed/sharded execution, watch mode,
process isolation, quarantine/flake-tracking, and snapshot testing are all
real resq features this project doesn't attempt to re-implement — they're
substantial subsystems in their own right (resq's coverage.q alone is
~110KB) and out of scope for what was meant to be a small, readable core.
If you need them, resq is the right tool; q-test is aimed at the common
case those frameworks all started from.
