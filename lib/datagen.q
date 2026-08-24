/ q-test :: schema-driven fixture data generation
/ .qt.datagen.forTable[emptyTable;n;overrides] fills an empty (or any)
/ table's schema with n rows of plausible-looking random data, inferring a
/ generator per column from its q type (via meta) and its name (a column
/ named like *sym*/*side*/*source* or *price*/*size* gets a more sensible
/ default than a bare type-only guess would). overrides lets a caller
/ replace any column's generator outright - built on the same .qt.gen.*
/ primitives used for property-based testing, not a separate mechanism.
/ .qt.datagen.forSchema[schemaPath;n;overrides] does the same for every
/ table a schema file defines (discovered the same way scaffold.q finds
/ functions: new top-level names after loading, filtered here to table-
/ typed ones), and - unlike scaffold.forFile, which only ever writes a
/ file - populates each table's own global variable with the generated
/ rows directly, so e.g. `quote` is immediately usable after the call.

\d .qt

/ ---- name-sensitive defaults -------------------------------------------
/ default instrument-style symbol pool: a realistic-looking mix, not
/ random garbage - openQ's own schema.q is FX/equity flavored (see its
/ README's efx integration), so this pool leans the same way
datagen.i.symPool:`AAPL`MSFT`GOOG`AMZN`TSLA`EURUSD`GBPUSD`USDJPY`AUDUSD;
datagen.i.sidePool:`buy`sell;
datagen.i.sourcePool:`EBS`REUTERS`LMAX`CITI`BARX;
datagen.i.genericSymPool:`A`B`C`D`E;

datagen.i.symGenFor:{[colName]
  nm:lower string colName;
  $[nm~"sym"; gen.sym datagen.i.symPool;
    nm~"side"; gen.sym datagen.i.sidePool;
    (nm like "*source*") or (nm like "*venue*") or (nm like "*feed*"); gen.sym datagen.i.sourcePool;
    gen.sym datagen.i.genericSymPool]
 };

datagen.i.floatGenFor:{[colName]
  nm:lower string colName;
  / size-ish checked first: "bidSize"/"askSize" contain "bid"/"ask" as
  / substrings too, so checking price-ish first would misclassify them
  $[(nm like "*size*") or (nm like "*qty*") or (nm like "*volume*") or (nm like "*notional*"); gen.float[100;1000000];
    (nm like "*price*") or (nm like "*bid*") or (nm like "*ask*"); gen.float[1;500];
    gen.float[0;1000]]
 };

/ default window for a timestamp/date column that isn't overridden: the
/ last 24h / most recent 30 days, ending now
datagen.i.defaultTsFrom:.z.p-1D;
datagen.i.defaultDateFrom:.z.d-30;

/ pick a generator for one column from its meta type-char and name; ` if
/ the type isn't one this can generate a plausible default for (that
/ column is left at its q-default null in every generated row)
datagen.i.genFor:{[colName;typeChar]
  $[typeChar="p"; gen.timestamp[datagen.i.defaultTsFrom;.z.p];
    typeChar="d"; gen.date[datagen.i.defaultDateFrom;.z.d];
    typeChar="s"; datagen.i.symGenFor colName;
    typeChar in "fe"; datagen.i.floatGenFor colName;
    typeChar in "jih"; gen.int[0;10000];
    typeChar="b"; gen.bool;
    `]
 };

/ ---- table generation ---------------------------------------------------
/ overrides: dict colName!generator (a .qt.gen.* style callable) for any
/ column whose default guess isn't right for this data
datagen.forTable:{[emptyTable;n;overrides]
  m:0!meta emptyTable;  / meta comes back keyed by column name - unkey first, or m`t below is a key lookup, not a column select
  colNames:m`c;
  types:m`t;
  / {[v;d] v}[overrides;] each colNames, not count[colNames]#enlist
  / overrides (a repeated single-key dict promotes to a real table under
  / #, the same same-keyed-dicts-auto-promote trap noted in runner.q) and
  / not {overrides} each colNames either (a nested lambda can't see its
  / enclosing function's own parameter, only true globals - overrides
  / must be projected in explicitly)
  overridesPerCol:{[v;d] v}[overrides;] each colNames;
  gens:{[colName;typeChar;overrides]
    $[colName in key overrides; overrides colName; datagen.i.genFor[colName;typeChar]]
   }'[colNames;types;overridesPerCol];
  / g[(::)] each til n is wrong - that calls g once, then tries to `each`
  / over its *result* as if that were a function. Need one fresh call per
  / element: a wrapper with g fixed via projection and a trailing unfilled
  / slot for `each` to drive, same pattern as gen.q's own generators.
  colVals:{[g;n] $[g~`; n#(::); {[g;i] g[(::)]}[g;] each til n]}[;n] each gens;
  t:flip colNames!colVals;
  t:0!(colNames#emptyTable) uj t;
  n#t
 };

/ ---- table generator, for use as a .qt.gen.* value ------------------------
/ gen.table[emptyTable;minRows;maxRows] - a proper generator (config now,
/ draw later, same shape as gen.int/gen.sym/...): each draw calls
/ datagen.forTable fresh with a random row count in [minRows;maxRows], so a
/ .qt.gen.forAll property test can take a whole random table as one of its
/ arguments instead of being limited to scalars. Lives here, not in
/ gen.q, so the dependency stays one-directional (datagen depends on gen,
/ not the other way around).
gen.i.table:{[emptyTable;minRows;maxRows;d] datagen.forTable[emptyTable;minRows+rand 1+maxRows-minRows;(`$())!()]};
gen.table:{[emptyTable;minRows;maxRows] gen.i.table[emptyTable;minRows;maxRows;]};

/ ---- schema-file discovery ------------------------------------------------
datagen.i.isTable:{[v] 98h=type v};

/ new top-level table variables that appeared after loading schemaPath
datagen.i.newTables:{[before]
  new:(key `.) except before;
  new where datagen.i.isTable each value each new
 };

/ generate rows for every table a schema file defines, and set each
/ table's own global to the generated rows (so `quote`/`trade` etc. are
/ immediately usable after this call). overrides is a dict
/ tableName!(colName!generator) - per-table column overrides; a table with
/ no entry gets every column's plain inferred default.
/ Returns a dict tableName!generatedTable.
datagen.forSchema:{[schemaPath;n;overrides]
  before:key `.;
  system "l ",schemaPath;
  tblNames:datagen.i.newTables before;
  results:{[n;overrides;tblName]
    tblOverrides:$[tblName in key overrides; overrides tblName; (`$())!()];
    r:datagen.forTable[value tblName;n;tblOverrides];
    tblName set r;
    r
   }[n;overrides] each tblNames;
  tblNames!results
 };

\d .
