/ q-test :: CLI launcher
/ Usage: q bin/qtest.q <path> [-junit <file>] [-strict]
/        q bin/qtest.q generate <srcFile.q> [-outDir <dir>]
/ <path> is a directory (its *_test.q / test_*.q / *_spec.q files are all
/ loaded) or a single .q file. `generate` scaffolds a *_test.q for a plain
/ source file instead of running anything (default -outDir is "tests").
/ Pure q, no shell/bash dependency - runs the same way on Windows, Linux,
/ and macOS.

.qt.cli.i.norm:{[p] ssr[p;"\\";"/"]};
.qt.cli.i.dirOf:{[p] parts:"/" vs .qt.cli.i.norm p; "/" sv -1 _ parts};

.qt.cli.i.selfDir:.qt.cli.i.dirOf string .z.f;
.qt.cli.i.libDir:.qt.cli.i.selfDir,"/../lib";

.qt.cli.i.load:{[f] system "l ",f};
.qt.cli.i.load each .qt.cli.i.libDir,/:("/assert.q";"/mock.q";"/discover.q";"/gen.q";"/runner.q";"/dsl.q";"/report.q";"/scaffold.q");

/ ---- arg parsing -------------------------------------------------------------
.qt.cli.i.args:.z.x;

/ ---- generate subcommand: scaffold a *_test.q and exit, no test run ------------
/ q bin/qtest.q generate <srcFile.q> [-outDir <dir>] - checked first and
/ handled with its own tiny parser, entirely separate from the test-running
/ path below, since its argument shape (a source file, not a test path) is
/ different in kind, not just in flags.
if[(count .qt.cli.i.args) and (first .qt.cli.i.args)~"generate";
  .qt.cli.i.genRest:1_.qt.cli.i.args;
  .qt.cli.i.odIdx:.qt.cli.i.genRest?"-outDir";
  .qt.cli.i.outDir:$[.qt.cli.i.odIdx<count .qt.cli.i.genRest; .qt.cli.i.genRest .qt.cli.i.odIdx+1; "tests"];
  .qt.cli.i.srcArgs:$[.qt.cli.i.odIdx<count .qt.cli.i.genRest;
    (.qt.cli.i.odIdx#.qt.cli.i.genRest),(.qt.cli.i.odIdx+2)_.qt.cli.i.genRest;
    .qt.cli.i.genRest];
  if[0=count .qt.cli.i.srcArgs;
    -2 "[q-test] usage: q bin/qtest.q generate <srcFile.q> [-outDir <dir>]";
    exit 4;
   ];
  .qt.cli.i.srcFile:first .qt.cli.i.srcArgs;
  .qt.cli.i.srcKey:key hsym `$.qt.cli.i.norm .qt.cli.i.srcFile;
  if[-11h<>type .qt.cli.i.srcKey;
    -2 "[q-test] source file not found: ",.qt.cli.i.srcFile;
    exit 4;
   ];
  .qt.cli.i.summary:.qt.scaffold.forFile[.qt.cli.i.srcFile;.qt.cli.i.outDir];
  .qt.cli.i.skipMsg:$[0=count .qt.cli.i.summary`skipped; "";
    ", ",string[count .qt.cli.i.summary`skipped]," skipped (unknown arity): ",", " sv string .qt.cli.i.summary`skipped];
  -1 "[q-test] wrote ",.qt.cli.i.summary[`written]," (",string[.qt.cli.i.summary`generated]," test case(s) generated",.qt.cli.i.skipMsg,")";
  exit 0;
 ];

.qt.cli.i.junitPath:`;
.qt.cli.i.strict:0b;
.qt.cli.i.target:`;

.qt.cli.i.parse:{
  a:.qt.cli.i.args;
  i:0;
  while[i<count a;
    $[a[i]~"-junit"; [.qt.cli.i.junitPath::a i+1; i+:2];
      a[i]~"-strict"; [.qt.cli.i.strict::1b; i+:1];
      [.qt.cli.i.target::a i; i+:1]]
   ];
 };
.qt.cli.i.parse[];

if[.qt.cli.i.target~`;
  -2 "[q-test] usage: q bin/qtest.q <path> [-junit <file>] [-strict]";
  -2 "         q bin/qtest.q generate <srcFile.q> [-outDir <dir>]";
  exit 4;
 ];

/ ---- file discovery -----------------------------------------------------------
.qt.cli.i.isTestFile:{[nm] (nm like "*_test.q") or (nm like "test_*.q") or (nm like "*_spec.q")};

/ key on a path returns: () (type 0h) if nothing exists there, a scalar
/ symbol (type -11h, the path itself) for a plain file, or a symbol list
/ (type 11h) of child names for a directory.
.qt.cli.i.targetSym:hsym `$.qt.cli.i.norm .qt.cli.i.target;
.qt.cli.i.targetKey:key .qt.cli.i.targetSym;
.qt.cli.i.files:$[11h=type .qt.cli.i.targetKey;
  [names:string .qt.cli.i.targetKey;
    .qt.cli.i.target,/:"/",/:names where .qt.cli.i.isTestFile each names];
  -11h=type .qt.cli.i.targetKey; enlist .qt.cli.i.target;
  ()];

if[0=count .qt.cli.i.files;
  -2 "[q-test] no test files found under ",.qt.cli.i.target;
  exit 3;
 ];

-1 "[q-test] loading ",string[count .qt.cli.i.files]," test file(s) from ",.qt.cli.i.target;
{-1 "  ",x; system "l ",x} each .qt.cli.i.files;

/ ---- run + report ---------------------------------------------------------------
.qt.runAll[];
.qt.cli.i.ok:.qt.report.summary[];

if[not .qt.cli.i.junitPath~`;
  .qt.report.junit[hsym `$.qt.cli.i.junitPath];
  -1 "[q-test] JUnit report written to ",.qt.cli.i.junitPath;
 ];

.qt.cli.i.noneRan:0=count .qt.results;
exit $[.qt.cli.i.strict and .qt.cli.i.noneRan; 1;
  not .qt.cli.i.ok; 1;
  0];
