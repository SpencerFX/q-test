/ q-test testing itself: BDD style exercising the shared assert/mock/gen
/ machinery. Run with: q bin/qtest.q tests/

.qt.describe["assert primitives"]{
  .qt.should["assertEquals passes on equal values"]{
    .qt.assertEquals[4;4;"4=4"] ~ 4
   };

  .qt.should["assertEquals fails on unequal values"]{
    caught:.[.qt.assertEquals;(1;2;"x");{x}];
    caught ~ .qt.ASSERT_TAG
   };

  .qt.should["assertThat supports arbitrary relations"]{
    .qt.assertThat[3;<;5;"3<5"] ~ 3
   };

  .qt.should["assertError catches a thrown error"]{
    (.qt.assertError[{'"boom"};(::);"should throw"]) ~ "boom"
   };

  .qt.should["assertError fails when the function does not throw"]{
    caught:.[.qt.assertError;({1+1};(::);"expected throw");{x}];
    caught ~ .qt.ASSERT_TAG
   };

  .qt.should["assertNoError passes a function through"]{
    .qt.assertNoError[{1+1};(::);"no throw"] ~ 2
   };
 };

.qt.describe["mock/restore"]{
  .qt.beforeAll{.a.b:11; .a.f:{x+10}};
  .qt.afterAll{.qt.restore[]};

  .qt.should["mocks an existing namespaced value and restores it"]{
    .qt.mock[`.a.b;22];
    r1:.a.b~22;
    .qt.restore[];
    r2:.a.b~11;
    r1 and r2
   };

  .qt.should["mocks an existing function and restores it"]{
    .qt.mock[`.a.f;{13}];
    r1:(.a.f 99)~13;
    .qt.restore[];
    r2:(.a.f 99)~109;
    r1 and r2
   };

  .qt.should["a brand-new bare top-level mock clears to null on restore, not its mocked value"]{
    .qt.mock[`brandNewTopLevel;100];
    r1:brandNewTopLevel~100;
    .qt.restore[];
    r2:(::)~brandNewTopLevel;
    r1 and r2
   };
 };

.qt.describe["property-based forAll"]{
  .qt.should["passes when the property genuinely holds for every trial"]{
    caught:.[.qt.gen.forAll;((.qt.gen.int[0;100];.qt.gen.int[0;100]);{[a;b](a+b)=(b+a)};"commutes");{x}];
    (::)~caught
   };

  .qt.should["fails and reports a counterexample when the property does not hold"]{
    caught:.[.qt.gen.forAll;((.qt.gen.int[0;50];.qt.gen.int[0;50]);{[a;b] a<b};"a<b always");{x}];
    caught ~ .qt.ASSERT_TAG
   };
 };

.qt.describe["convention-based discovery"]{
  .qt.beforeAll{
    .qtSelfTestNs.testOne:{1};
    .qtSelfTestNs.setUpEach:{};
    .qtSelfTestNs.tearDownEach:{};
    .qtSelfTestNs.beforeAllOnce:{};
    .qtSelfTestNs.notATest:5;
   };

  .qt.should["finds test*/setUp*/tearDown*/beforeAll* by naming convention only"]{
    d:.qt.discover.byPrefix[`.qtSelfTestNs];
    (d[`test]~enlist `.qtSelfTestNs.testOne) and
      (d[`setUp]~enlist `.qtSelfTestNs.setUpEach) and
      (d[`tearDown]~enlist `.qtSelfTestNs.tearDownEach) and
      (d[`beforeAll]~enlist `.qtSelfTestNs.beforeAllOnce)
   };

  .qt.should["ignores non-function data that happens to match the naming convention"]{
    not `.qtSelfTestNs.notATest in .qt.discover.byPrefix[`.qtSelfTestNs][`test]
   };
 };

.qt.describe["scaffold generation"]{
  / writes into a hidden, gitignored-by-convention scratch dir under tests/
  / rather than the repo's real tests/ or examples/ - the launcher only
  / scans a directory's top level, so this subdirectory is never picked up
  / by a plain `q bin/qtest.q tests/` run.

  .qt.should["finds the namespace a source file switches into"]{
    .qt.scaffold.i.findNamespace["examples/math.q"] ~ `.math
   };

  .qt.should["reports arity via a loaded function's own value"]{
    (.qt.scaffold.i.arity {[a;b;c] a+b+c}) ~ 3
   };

  .qt.should["generates a runnable test file with one case per real function"]{
    r:.qt.scaffold.forFile["examples/math.q";"tests/.scratch";`];
    (r[`generated]~3) and (0=count r`skipped) and (r[`written]~"tests/.scratch/math_test.q")
   };

  .qt.should["the generated file itself loads and its cases pass"]{
    before:count .qt.results;
    system "l tests/.scratch/math_test.q";
    .qt.runNamespace[`.mathTest];
    newRows:(count .qt.results)-before;
    lastN:(neg newRows)#.qt.results;
    (newRows>0) and all lastN[`status]=`pass
   };
 };

.qt.describe["gen.table"]{
  .qt.should["draws a fresh table each call, row count within the requested range"]{
    q:([] sym:`symbol$(); px:`float$());
    g:.qt.gen.table[q;2;4];
    t1:g[(::)];
    t2:g[(::)];
    ((cols q)~cols t1) and (count[t1] within 2 4) and (count[t2] within 2 4)
   };
 };

.qt.describe["scaffold schema-awareness"]{
  / schemaContext discovers a schema's tables via a root-diff (the same
  / technique scaffold.q uses for functions) - so it only sees them as
  / "new" the *first* time a given schema file's tables get created in
  / this session. A second call (even for the same file) finds zero new
  / tables, since q can never truly remove a bare top-level name once
  / created (see q_kdb_gotchas.md), and returns ` instead of a real
  / context. Computing it once via beforeAll and storing it in a real
  / global (not a describe-block local - the collection-phase block only
  / *collects* should/beforeAll, it doesn't share locals with their later,
  / deferred execution) avoids every should needing its own fresh call.
  .qt.beforeAll{`.qtSelfTest.schemaCtx set .qt.scaffold.i.schemaContext["examples/schema.q"]};

  .qt.should["reads a lambda's own declared parameter names, not just its arity"]{
    .qt.scaffold.i.paramNames[{[tab;keyCols] tab}] ~ `tab`keyCols
   };

  .qt.should["schemaContext finds the representative table and classifies its symbol/float columns"]{
    ctx:.qtSelfTest.schemaCtx;
    (ctx[`repTableVar]~"quote") and (`sym in ctx`symCols) and (`bid in ctx`floatCols)
   };

  .qt.should["a table-shaped parameter name picks the schema-aware table generator, referenced via value`name"]{
    / a bare name inside a function defined under \d .someTest resolves
    / only relative to .someTest, with no fallback to root - see
    / q_kdb_gotchas.md. Generated test bodies live under \d .xTest, so the
    / schema table reference must be `value `tableName`, never the bare
    / table name, or every table-shaped case fails to even construct its
    / generator when the generated file is actually run.
    gen:.qt.scaffold.i.paramGenStr[`tab;.qtSelfTest.schemaCtx];
    (gen like "*gen.table*") and (gen like "*value `quote*")
   };

  .qt.should["a cols-shaped parameter name picks a real column name, not a made-up one"]{
    (.qt.scaffold.i.paramGenStr[`keyCols;.qtSelfTest.schemaCtx]) like "*`sym*"
   };

  .qt.should["without a schema, falls back to the original plain-int generator unchanged"]{
    (.qt.scaffold.i.paramGenStr[`tab;`]) ~ ".qt.gen.int[-100;100]"
   };
 };

.qt.describe["schema-driven data generation"]{
  / not a shared local: describe's block only *collects* should/skip/
  / pending - each body below runs later, in its own deferred call, where
  / a plain local from the collection-phase block no longer exists. Each
  / should inlines its own empty table instead.

  .qt.should["generates the requested row count with the schema's own column names and types"]{
    emptyQuote:([] timestamp:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$());
    r:.qt.datagen.forTable[emptyQuote;7;(`$())!()];
    (count[r]~7) and ((cols emptyQuote)~cols r) and (0!meta[r])~0!meta emptyQuote
   };

  .qt.should["an empty overrides dict still produces non-null generated values"]{
    emptyQuote:([] timestamp:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$());
    r:.qt.datagen.forTable[emptyQuote;5;(`$())!()];
    (not any null r`bid) and (not any null r`sym)
   };

  .qt.should["a per-column override replaces the default generator for just that column"]{
    emptyQuote:([] timestamp:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$());
    r:.qt.datagen.forTable[emptyQuote;5;(enlist `sym)!enlist .qt.gen.sym enlist `XAUUSD];
    all r[`sym]=`XAUUSD
   };

  .qt.should["forSchema discovers every table a schema file defines and populates its global"]{
    r:.qt.datagen.forSchema["examples/schema.q";4;(`$())!()];
    (key[r]~`quote`trade) and (count[quote]~4) and (count[trade]~4)
   };

  .qt.should["bidSize/askSize get size-range values, not price-range, despite containing bid/ask"]{
    r:.qt.datagen.forTable[([] bidSize:`float$(); bid:`float$());20;(`$())!()];
    / size range starts at 100, price range tops out at 500 - a size
    / column drawing consistently below 100 across 20 rows would mean the
    / bid/ask substring match won (the bug this test guards against)
    any r[`bidSize]>500
   };
 };
