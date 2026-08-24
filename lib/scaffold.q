/ q-test :: test-file scaffolding
/ .qt.scaffold.forFile[srcPath;outDir] loads a plain .q source file, finds
/ the functions it defines, and writes a ready-to-run *_test.q file next to
/ it: a .qt.gen.forAll smoke test per function (generic int generators - a
/ starting point, not a finished test) for everything it can determine the
/ arity of.
/ Unlike q-desc's testFramework (which requires a //@param annotation
/ comment for every parameterized function before it will fuzz it), this
/ needs no annotation step - it reads real arity off the loaded function
/ via `value`, generates its best guess, and clearly marks the guess as
/ something to refine, in both the file header and each generated case.

\d .qt

/ ---- source inspection -----------------------------------------------------
/ the namespace a line's assignment target lives directly under, e.g.
/ ".util.core.obfus:{...}" -> `.util.core (everything but the final,
/ function-name segment - not just the first segment: a file conventionally
/ namespaced two or more levels deep, like this one, has its real functions
/ a level below where the first segment alone would point). ` if the line
/ isn't a dotted top-level assignment at all (root-diff-only \d/
/ newRootFunctions files never match this, harmlessly).
scaffold.i.dottedNs:{[line]
  colonAt:line ss ":";
  if[0=count colonAt; :`];
  head:(first colonAt)#line;
  if[(0=count head) or not "."=first head; :`];
  parts:"." vs head;
  if[3>count parts; :`];
  `$"." sv -1_parts
 };

/ the namespace a source file's functions live in: either an explicit
/ "\d .foo" line, or - the more common convention in practice, used
/ throughout this very codebase (openQ) - the namespace most of the file's
/ fully-qualified top-level assignments share (".util.core.obfus:{...}",
/ no \d at all). The *most common* dotted prefix, not just the first
/ line's: a file's first dotted assignment is sometimes an outlier (e.g. a
/ single nested state flag one level deeper than every real function, as
/ in openQ's utils/core.q's own .util.core.info.loaded), and trusting only
/ that line would point one level too deep for everything else. () wrapped
/ as ` if neither is found (the file only defines bare top-level names;
/ scaffold.forFile falls back to a root-key diff then).
scaffold.i.findNamespace:{[srcPath]
  lines:read0 hsym `$srcPath;
  dMatches:lines where lines like "\\d *";
  if[count dMatches;
    ns:`$3_first dMatches;
    if[not ns~`.; :ns];
   ];
  dotted:scaffold.i.dottedNs each lines;
  dotted:dotted where not dotted~\:`;
  if[0=count dotted; :`];
  counts:count each group dotted;
  cKeys:key counts;
  cVals:value counts;
  first cKeys where cVals=max cVals
 };

scaffold.i.isFunc:{[v] (type v) within 100 112h};

/ arity of a plain lambda (100h); -1 if not a plain lambda (projection,
/ composition, primitive, ...) - those are skipped, not guessed at.
/ Note every lambda reports arity >=1 here, even {[] ...} (explicit empty
/ params) and bare {...} with no x/y/z referenced at all - q always gives
/ a plain lambda at least one declared parameter slot.
scaffold.i.arity:{[f] $[100h=type f; count value[f] 1; -1]};

/ the lambda's own declared parameter names (e.g. `tab`keyCols for
/ {[tab;keyCols] ...}) - used, when a schema is supplied, to decide which
/ argument should be a table/column-list/etc instead of a plain int
scaffold.i.paramNames:{[f] $[100h=type f; value[f] 1; `symbol$()]};

/ every plain-function child directly under namespace ns. `key ns` includes
/ a spurious leading empty-symbol entry (an internal namespace artifact,
/ not a real child) - drop it before qualifying names.
scaffold.i.functionsIn:{[ns]
  names:key[ns] where key[ns]<>`;
  quals:{[ns;nm] ` sv ns,nm}[ns] each names;
  quals where scaffold.i.isFunc each value each quals
 };

/ functions that appeared at root between two `key `.` snapshots
scaffold.i.newRootFunctions:{[before]
  new:(key `.) except before;
  new where scaffold.i.isFunc each value each new
 };

/ ---- schema-aware argument generation ---------------------------------------
/ loads schemaPath and picks one representative table (the first table it
/ defines - see scaffold.forFile's doc comment for why just one) plus that
/ table's symbol- and float-typed column names, for name-based per-argument
/ generator selection below. ` (not a dict) if schemaPath is ` (no schema
/ given) or the file defines no tables at all - callers treat that as
/ "fall back to the plain generic-int behaviour".
scaffold.i.schemaContext:{[schemaPath]
  if[schemaPath~`; :`];
  before:key `.;
  system "l ",schemaPath;
  tblNames:datagen.i.newTables before;
  if[0=count tblNames; :`];
  repName:first tblNames;
  repTable:value repName;
  m:0!meta repTable;
  symCols:m[`c] where m[`t]="s";
  floatCols:m[`c] where m[`t] in "fe";
  `repTableVar`symCols`floatCols!(string repName;symCols;floatCols)
 };

/ a q source-code literal for a list of symbols, safe for a single element
/ too (a bare `sym alone is an atom, not a 1-element list - `count`/index
/ on it inside .qt.gen.oneOf would misbehave)
scaffold.i.symListLit:{[syms]
  $[1=count syms; "enlist `",string first syms; raze "`",/:string syms]
 };

/ pick a generator EXPRESSION (source text) for one parameter, from its own
/ name and the representative table's shape. schemaCtx ~ ` (no schema
/ given, or the schema defines no tables) always falls back to the plain
/ int generator, same as every parameter got before this existed.
scaffold.i.paramGenStr:{[paramName;schemaCtx]
  if[schemaCtx~`; :".qt.gen.int[-100;100]"];
  nm:lower string paramName;
  symCols:schemaCtx`symCols;
  floatCols:schemaCtx`floatCols;
  $[(nm like "*tab*") or (nm like "*table*");
      / value `name, not the bare table name: a bare unqualified name
      / inside a function defined under \d .someTestNs resolves relative
      / to .someTestNs (with no fallback search up to root) even when the
      / call site is fully qualified - only a dynamic symbol lookup
      / reliably reaches a same-named root-level global from there
      ".qt.gen.table[value `",schemaCtx[`repTableVar],";1;5]";
    nm like "*cols*";
      $[0=count symCols;
        ".qt.gen.oneOf[enlist `$()]";
        ".qt.gen.oneOf[(`$();enlist `",string[first symCols],")]"];
    nm~"bucket";
      ".qt.gen.oneOf[`hour`minute`second`date]";
    nm like "*percentile*";
      ".qt.gen.oneOf[(enlist 0.5;0.5 0.9;0.5 0.9 0.99)]";
    (nm like "*col*") and (0<count floatCols);
      ".qt.gen.oneOf[",scaffold.i.symListLit[floatCols],"]";
    (nm like "*col*") and (0<count symCols);
      ".qt.gen.oneOf[",scaffold.i.symListLit[symCols],"]";
    ".qt.gen.int[-100;100]"]
 };

/ ---- code generation --------------------------------------------------------
scaffold.i.titleCase:{[s] (upper first s),1_s};

scaffold.i.testName:{[fname] `$"test",scaffold.i.titleCase string last ` vs fname};

/ one generated test-case line for function fname (fully qualified symbol),
/ () if its arity couldn't be determined (skipped). Every real lambda goes
/ through the same forAll-based smoke test, since q reports every lambda
/ as arity >=1 (see scaffold.i.arity) - there is no separate niladic case.
/ schemaCtx is scaffold.i.schemaContext's result: ` for the plain
/ generic-int behaviour, or a real context dict to generate table/column/
/ bucket/percentile-shaped arguments by parameter name instead.
scaffold.i.genCase:{[fname;schemaCtx]
  f:value fname;
  ar:scaffold.i.arity f;
  $[ar<0; (); ar>8; (); scaffold.i.genForAllCase[fname;ar;scaffold.i.paramNames f;schemaCtx]]
 };

scaffold.i.genForAllCase:{[fname;ar;paramNames;schemaCtx]
  tn:scaffold.i.testName fname;
  fs:string fname;
  ps:`$"p",/:string 1+til ar;
  psStr:";" sv string ps;
  gensList:$[schemaCtx~`;
    ar#enlist ".qt.gen.int[-100;100]";
    scaffold.i.paramGenStr[;schemaCtx] each paramNames];
  gensStr:";" sv gensList;
  argListStr:$[ar=1; "enlist ",first string ps; "(",psStr,")"];
  noteText:$[schemaCtx~`;
    " - review the generators above, real arg types may differ";
    " - schema-aware generators (table/column/bucket-shaped where the parameter name suggested it); still review before relying on it"];
  / no leading whitespace: an indented top-level statement silently fails
  / to register at all when the file is loaded (unlike inside a {} body,
  / where indentation is only cosmetic) - see q_kdb_gotchas.md
  enlist string[tn],":{.qt.gen.forAll[(",gensStr,");{[",psStr,"] .qt.assertNoErrorArgs[",fs,";",argListStr,";\"survives generated input\"];1b};\"",fs," survives random input (auto-generated",noteText,")\"]};"
 };

/ ---- orchestration -----------------------------------------------------------
scaffold.i.baseName:{[srcPath]
  noExt:$[srcPath like "*.q"; -2_srcPath; srcPath];
  parts:"/" vs ssr[noExt;"\\";"/"];
  last parts
 };

/ generate a *_test.q scaffold for srcPath, write it under outDir, return a
/ summary dict `written`generated`skipped!(filePath;n;list of skipped names).
/ schemaPath is ` for the original generic-int-only behaviour, or a schema
/ file (table shapes only, e.g. what .qt.datagen.forSchema consumes) to
/ generate real table/column/bucket-shaped arguments for parameters whose
/ own name suggests that's what they are (tab/table, keyCols/extraKeyCols,
/ bucket, percentiles, refCol/valCol/timeCol). Only the *first* table the
/ schema defines is used, for every table-shaped parameter of every
/ function - q carries no argument type information to match a specific
/ parameter to a specific table by, and for a single-table-shape domain
/ (most schemas, and specifically the quote/trade shape this was built
/ against) that one table is the right guess for all of them anyway.
scaffold.forFile:{[srcPath;outDir;schemaPath]
  before:key `.;
  ns:scaffold.i.findNamespace srcPath;
  system "l ",srcPath;
  fns:$[ns~`; scaffold.i.newRootFunctions before; scaffold.i.functionsIn ns];

  schemaCtx:scaffold.i.schemaContext schemaPath;

  cases:scaffold.i.genCase[;schemaCtx] each fns;
  skipped:fns where 0=count each cases;
  kept:fns where 0<count each cases;
  bodyLines:raze cases where 0<count each cases;

  base:scaffold.i.baseName srcPath;
  testNs:`$"." ,base,"Test";
  outPath:outDir,"/",base,"_test.q";

  regenLine:$[schemaPath~`;
    "/ Regenerate with: q bin/qtest.q generate ",srcPath;
    "/ Regenerate with: q bin/qtest.q generate ",srcPath," -schema ",schemaPath];
  srcLoadLine:"system \"l ",srcPath,"\";";
  schemaLoadLines:$[schemaPath~`; (); enlist "system \"l ",schemaPath,"\";"];
  titleLines:("/ AUTO-GENERATED by q-test scaffold - review before relying on it.";"/ Generated from: ",srcPath;regenLine;"");
  loadLines:(enlist srcLoadLine),schemaLoadLines;
  dLine:enlist "\\d ",string testNs;
  header:titleLines,loadLines,(enlist ""),dLine;
  footer:("";"\\d .";".qt.register[`",string[testNs],"];");

  lines:header,bodyLines,footer;
  (hsym `$outPath) 0: lines;

  `written`generated`skipped!(outPath;count kept;skipped)
 };

\d .
