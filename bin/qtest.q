/ q-test :: CLI launcher
/ Usage: q bin/qtest.q <path> [-junit <file>] [-strict]
/        q bin/qtest.q generate <srcFile.q> [-outDir <dir>] [-schema <schemaFile.q>]
/        q bin/qtest.q datagen <schemaFile.q> [-rows N] [-save <dir>]
/ <path> is a directory (its *_test.q / test_*.q / *_spec.q files are all
/ loaded) or a single .q file. `generate` scaffolds a *_test.q for a plain
/ source file instead of running anything (default -outDir is "tests");
/ -schema gives it real table/column-shaped generators for parameters that
/ look like they take one, instead of only ever generating plain ints.
/ `datagen` fills every table a schema file defines with N random rows
/ (default 100) and either previews them or, with -save, serializes each
/ to its own file under <dir>. Pure q, no shell/bash dependency - runs the
/ same way on Windows, Linux, and macOS.

.qt.cli.i.norm:{[p] ssr[p;"\\";"/"]};
.qt.cli.i.dirOf:{[p] parts:"/" vs .qt.cli.i.norm p; "/" sv -1 _ parts};

.qt.cli.i.selfDir:.qt.cli.i.dirOf string .z.f;
.qt.cli.i.libDir:.qt.cli.i.selfDir,"/../lib";

.qt.cli.i.load:{[f] system "l ",f};
.qt.cli.i.load each .qt.cli.i.libDir,/:("/assert.q";"/mock.q";"/discover.q";"/gen.q";"/runner.q";"/dsl.q";"/report.q";"/scaffold.q";"/datagen.q");

/ ---- arg parsing -------------------------------------------------------------
.qt.cli.i.args:.z.x;

/ ---- generate subcommand: scaffold a *_test.q and exit, no test run ------------
/ q bin/qtest.q generate <srcFile.q> [-outDir <dir>] [-schema <schemaFile.q>]
/ - checked first and handled with its own tiny parser, entirely separate
/ from the test-running path below, since its argument shape (a source
/ file, not a test path) is different in kind, not just in flags. -schema
/ points at a table-shapes-only schema file (what .qt.datagen.forSchema
/ also consumes) so table/column/bucket-shaped parameters get real-looking
/ generators instead of plain ints - see lib/scaffold.q's forFile doc.
if[(count .qt.cli.i.args) and (first .qt.cli.i.args)~"generate";
  .qt.cli.i.genRest:1_.qt.cli.i.args;
  .qt.cli.i.odIdx:.qt.cli.i.genRest?"-outDir";
  .qt.cli.i.outDir:$[.qt.cli.i.odIdx<count .qt.cli.i.genRest; .qt.cli.i.genRest .qt.cli.i.odIdx+1; "tests"];
  .qt.cli.i.genRest:$[.qt.cli.i.odIdx<count .qt.cli.i.genRest;
    (.qt.cli.i.odIdx#.qt.cli.i.genRest),(.qt.cli.i.odIdx+2)_.qt.cli.i.genRest;
    .qt.cli.i.genRest];
  .qt.cli.i.scIdx:.qt.cli.i.genRest?"-schema";
  .qt.cli.i.schemaFile:$[.qt.cli.i.scIdx<count .qt.cli.i.genRest; .qt.cli.i.genRest .qt.cli.i.scIdx+1; `];
  .qt.cli.i.srcArgs:$[.qt.cli.i.scIdx<count .qt.cli.i.genRest;
    (.qt.cli.i.scIdx#.qt.cli.i.genRest),(.qt.cli.i.scIdx+2)_.qt.cli.i.genRest;
    .qt.cli.i.genRest];
  if[0=count .qt.cli.i.srcArgs;
    -2 "[q-test] usage: q bin/qtest.q generate <srcFile.q> [-outDir <dir>] [-schema <schemaFile.q>]";
    exit 4;
   ];
  .qt.cli.i.srcFile:first .qt.cli.i.srcArgs;
  .qt.cli.i.srcKey:key hsym `$.qt.cli.i.norm .qt.cli.i.srcFile;
  if[-11h<>type .qt.cli.i.srcKey;
    -2 "[q-test] source file not found: ",.qt.cli.i.srcFile;
    exit 4;
   ];
  if[not .qt.cli.i.schemaFile~`;
    .qt.cli.i.schemaKey:key hsym `$.qt.cli.i.norm .qt.cli.i.schemaFile;
    if[-11h<>type .qt.cli.i.schemaKey;
      -2 "[q-test] schema file not found: ",.qt.cli.i.schemaFile;
      exit 4;
     ];
   ];
  .qt.cli.i.summary:.qt.scaffold.forFile[.qt.cli.i.srcFile;.qt.cli.i.outDir;.qt.cli.i.schemaFile];
  .qt.cli.i.skipMsg:$[0=count .qt.cli.i.summary`skipped; "";
    ", ",string[count .qt.cli.i.summary`skipped]," skipped (unknown arity): ",", " sv string .qt.cli.i.summary`skipped];
  -1 "[q-test] wrote ",.qt.cli.i.summary[`written]," (",string[.qt.cli.i.summary`generated]," test case(s) generated",.qt.cli.i.skipMsg,")";
  exit 0;
 ];

/ ---- datagen subcommand: fill a schema's tables with random rows --------------
if[(count .qt.cli.i.args) and (first .qt.cli.i.args)~"datagen";
  .qt.cli.i.dgRest:1_.qt.cli.i.args;
  .qt.cli.i.rowsIdx:.qt.cli.i.dgRest?"-rows";
  .qt.cli.i.rows:$[.qt.cli.i.rowsIdx<count .qt.cli.i.dgRest; "I"$.qt.cli.i.dgRest .qt.cli.i.rowsIdx+1; 100];
  .qt.cli.i.dgRest:$[.qt.cli.i.rowsIdx<count .qt.cli.i.dgRest;
    (.qt.cli.i.rowsIdx#.qt.cli.i.dgRest),(.qt.cli.i.rowsIdx+2)_.qt.cli.i.dgRest;
    .qt.cli.i.dgRest];
  .qt.cli.i.saveIdx:.qt.cli.i.dgRest?"-save";
  .qt.cli.i.saveDir:$[.qt.cli.i.saveIdx<count .qt.cli.i.dgRest; .qt.cli.i.dgRest .qt.cli.i.saveIdx+1; `];
  .qt.cli.i.dgRest:$[.qt.cli.i.saveIdx<count .qt.cli.i.dgRest;
    (.qt.cli.i.saveIdx#.qt.cli.i.dgRest),(.qt.cli.i.saveIdx+2)_.qt.cli.i.dgRest;
    .qt.cli.i.dgRest];
  if[0=count .qt.cli.i.dgRest;
    -2 "[q-test] usage: q bin/qtest.q datagen <schemaFile.q> [-rows N] [-save <dir>]";
    exit 4;
   ];
  .qt.cli.i.schemaFile:first .qt.cli.i.dgRest;
  .qt.cli.i.schemaKey:key hsym `$.qt.cli.i.norm .qt.cli.i.schemaFile;
  if[-11h<>type .qt.cli.i.schemaKey;
    -2 "[q-test] schema file not found: ",.qt.cli.i.schemaFile;
    exit 4;
   ];
  .qt.cli.i.dgResult:.qt.datagen.forSchema[.qt.cli.i.schemaFile;.qt.cli.i.rows;(`$())!()];
  .qt.cli.i.dgNames:key .qt.cli.i.dgResult;
  -1 "[q-test] generated ",string[.qt.cli.i.rows]," row(s) for ",string[count .qt.cli.i.dgNames]," table(s): ",", " sv string .qt.cli.i.dgNames;
  $[.qt.cli.i.saveDir~`;
    / (5&count t)#t, not bare 5#t: taking more rows than a table has
    / wraps around and repeats from the top instead of just giving what's there
    {t:.qt.cli.i.dgResult x; show (5&count t)#t; -1 "  (",string[x],": ",string[count t]," row(s) total)"} each .qt.cli.i.dgNames;
    [{[dir;dgResult;nm] (hsym `$dir,"/",string[nm],".qbin") set dgResult nm}[.qt.cli.i.saveDir;.qt.cli.i.dgResult] each .qt.cli.i.dgNames;
     -1 "[q-test] saved to ",.qt.cli.i.saveDir,"/{",(", " sv string .qt.cli.i.dgNames),"}.qbin"]];
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
