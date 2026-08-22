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
    r:.qt.scaffold.forFile["examples/math.q";"tests/.scratch"];
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
