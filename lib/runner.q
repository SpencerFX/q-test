/ q-test :: shared execution engine
/ .qt.i.runOne is the single primitive both the convention-based runner
/ (test* functions) and the BDD DSL (should blocks) execute through, so
/ pass/fail/error, timing, and memory are computed identically and reported
/ in one shared schema no matter which style produced the test.

\d .qt

/ Joining same-keyed dicts in this q build auto-promotes the accumulator to
/ a real column-typed table - so result/actual/expected (fields that
/ legitimately hold wildly different value types across different tests:
/ numbers, booleans, symbols, tables...) are stored *boxed* (enlist-wrapped)
/ in every row. A boxed column stays general no matter what's inside each
/ box, so two already-realized result tables concatenate safely even when
/ one test's result was a long and another's was a boolean. i.unbox (below,
/ next to i.runOne) undoes the boxing for a single row's real value.
resultCols:`status`name`result`actual`expected`msg`time`mem;
i.emptyResults:([] status:`symbol$();name:`symbol$();result:();actual:();expected:();msg:();time:`long$();mem:`long$());

registeredNamespaces:`symbol$();  / convention-style namespaces to run, via .qt.register
results:i.emptyResults;           / accumulated across the whole process

/ run a single niladic test function, protected, timed, memory-tracked.
i.runOne:{[name;fn]
  m0:.Q.w[][`used];
  t0:.z.p;
  r:@[{(`pass;x[];`;`;"")};fn;{[tag;e]
      $[e~tag; (`fail;.qt.lastFailure`actual;.qt.lastFailure`actual;.qt.lastFailure`expected;.qt.lastFailure`msg);
        (`error;`;`;`;e)]
     }[ASSERT_TAG]];
  t1:.z.p; m1:.Q.w[][`used];
  / result/actual/expected are boxed (enlist-wrapped): different tests return
  / wildly different value types there, and once two already-accumulated
  / result tables each have a concretely different atomic type for the same
  / column, concatenating them raises 'type - a boxed (list-of-1) cell keeps
  / the column genuinely general instead. i.unbox below undoes this for
  / display/programmatic access to a single row's actual value.
  `status`name`result`actual`expected`msg`time`mem!
    (r 0;name;enlist r 1;enlist r 2;enlist r 3;r 4;`long$(t1-t0)%1000000;m1-m0)
 };

/ pull a boxed result/actual/expected cell back out to its real value.
/ Always exactly one enlist was applied when the row was built (i.runOne
/ above), regardless of what's inside - so unboxing is always just `first`,
/ never a type-conditional check (enlist 3 is a plain long list, enlist
/ `sym is a symbol list, etc - there's no single wrapper type to detect).
i.unbox:{[x] first x};

/ ---- pollution guard -------------------------------------------------------
/ snapshot root's direct children before/after a unit of work; report any
/ brand-new top-level name it left behind (a real leak - locals inside
/ functions never show up here, only bare top-level assignments).
i.rootSnapshot:{key `.};
i.pollutionCheck:{[before;label]
  after:i.rootSnapshot[];
  leaked:after except before;
  if[count leaked;
    -2 "[q-test] WARNING: ",label," left new top-level name(s): ",
      (", " sv string leaked),". Consider .qt.mock/.qt.restore instead of bare assignment.";
   ];
 };

/ ---- convention-based (discover.q) orchestration --------------------------
/ run every test* in namespace ns once, honoring setUp/tearDown/beforeAll/
/ afterAll. Returns a result table for just this pass.
i.runNamespaceOnce:{[ns]
  d:discover.byPrefix[ns];
  rows:i.emptyResults;
  beforeAllOk:1b;
  if[count d`beforeAll;
    beforeAllOk:@[{value[x][];1b};first d`beforeAll;{-2 "[q-test] beforeAll failed: ",x;0b}];
   ];
  if[beforeAllOk;
    rows:{[d;acc;nm]
      if[count d`setUp; @[{value[x][]};first d`setUp;{-2 "[q-test] setUp failed (",string[nm],"): ",x}]];
      row:i.runOne[nm;value nm];
      if[count d`tearDown; @[{value[x][]};first d`tearDown;{-2 "[q-test] tearDown failed (",string[nm],"): ",x}]];
      acc,enlist row
     }[d]/[rows;d`test];
   ];
  if[not beforeAllOk;
    rows,:enlist `status`name`result`actual`expected`msg`time`mem!
      (`error;ns;enlist `;enlist `;enlist `;"beforeAll failed - tests skipped";0;0);
   ];
  if[count d`afterAll;
    @[{value[x][]};first d`afterAll;{-2 "[q-test] afterAll failed: ",x}];
   ];
  rows
 };

/ run namespace ns, expanding over `parameters` if the namespace declares
/ one; each parameter value is bound to ns.parameter before that pass.
runNamespace:{[ns]
  before:i.rootSnapshot[];
  rows:$[discover.hasParameters ns;
    {[ns;acc;p] (` sv ns,`parameter) set p; acc,i.runNamespaceOnce[ns]}[ns]/[i.emptyResults;value[` sv ns,`parameters][]];
    i.runNamespaceOnce[ns]];
  i.pollutionCheck[before;"namespace ",string ns];
  results,:rows;
  rows
 };

/ register a convention-style namespace to be picked up by .qt.runAll[]
register:{[ns] registeredNamespaces::distinct registeredNamespaces,ns;};

/ run every registered convention namespace and every DSL suite collected
/ so far (dsl.q populates .qt.results directly as suites execute, so this
/ mainly drives the convention side and returns everything accumulated).
runAll:{
  runNamespace each registeredNamespaces;
  results
 };

\d .
