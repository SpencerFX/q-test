/ q-test :: BDD-style DSL (describe/should), sharing the same execution
/ engine and result schema as the convention-based runner (runner.q's
/ i.runOne). describe[title]{block} runs block once to COLLECT should/
/ skip/pending/before/after/beforeAll/afterAll calls (block does not run
/ test bodies itself), then executes everything it collected, in
/ declaration order, with hooks fully known regardless of where in the
/ block they were declared.

\d .qt

dsl.i.blank:`title`shoulds`before`after`beforeAll`afterAll!(`;();(::);(::);(::);(::));
dsl.i.cur:dsl.i.blank;

/ ---- collection (called from inside a desc[] block) -----------------------
should:{[name;fn] dsl.i.cur[`shoulds]:dsl.i.cur[`shoulds],enlist `name`kind`fn!(name;`test;fn)};
skip:{[name;fn] dsl.i.cur[`shoulds]:dsl.i.cur[`shoulds],enlist `name`kind`fn!(name;`skip;fn)};
skipIf:{[cond;name;fn] $[cond;skip[name;fn];should[name;fn]]};
pending:{[name] dsl.i.cur[`shoulds]:dsl.i.cur[`shoulds],enlist `name`kind`fn!(name;`pending;{::})};
before:{[fn] dsl.i.cur[`before]:fn};
after:{[fn] dsl.i.cur[`after]:fn};
beforeAll:{[fn] dsl.i.cur[`beforeAll]:fn};
afterAll:{[fn] dsl.i.cur[`afterAll]:fn};

/ ---- execution (called once desc[]'s block has finished collecting) -------
dsl.i.skipRow:{[status;fullName]
  `status`name`result`actual`expected`msg`time`mem!
    (status;fullName;enlist(::);enlist(::);enlist(::);"";0;0)
 };

dsl.i.runItem:{[suite;fullName;item]
  $[item[`kind]=`skip; dsl.i.skipRow[`skip;fullName];
    item[`kind]=`pending; dsl.i.skipRow[`pending;fullName];
    dsl.i.runTestItem[suite;fullName;item]]
 };

dsl.i.runTestItem:{[suite;fullName;item]
  if[not (::)~suite`before; @[{x[]};suite`before;{-2 "[q-test] before failed: ",x}]];
  row:i.runOne[fullName;item`fn];
  if[not (::)~suite`after; @[{x[]};suite`after;{-2 "[q-test] after failed: ",x}]];
  row
 };

dsl.i.runSuite:{[suite]
  before:i.rootSnapshot[];
  beforeAllOk:1b;
  if[not (::)~suite`beforeAll;
    beforeAllOk:@[{x[];1b};suite`beforeAll;{-2 "[q-test] beforeAll failed: ",x;0b}];
   ];
  rows:$[beforeAllOk;
    {[suite;acc;item]
      fullName:`$suite[`title],": ",item`name;
      acc,enlist dsl.i.runItem[suite;fullName;item]
     }[suite]/[();suite`shoulds];
    enlist dsl.i.skipRow[`error;`$suite[`title],": (beforeAll failed)"]];
  if[not (::)~suite`afterAll;
    @[{x[]};suite`afterAll;{-2 "[q-test] afterAll failed: ",x}];
   ];
  i.pollutionCheck[before;"desc \"",suite[`title],"\""];
  results,:rows;
  rows
 };

/ ---- public entry point ----------------------------------------------------
/ named `describe`, not `desc` - `desc` is a reserved q keyword (descending
/ sort/attribute) and cannot be assigned at all, even inside a namespace.
describe:{[title;block]
  saved:dsl.i.cur;  / support nested/sequential describe[] blocks safely
  dsl.i.cur::`title`shoulds`before`after`beforeAll`afterAll!(title;();(::);(::);(::);(::));
  block[];
  suite:dsl.i.cur;
  dsl.i.cur::saved;
  dsl.i.runSuite[suite]
 };

\d .
