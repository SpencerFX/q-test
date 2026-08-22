/ q-test :: assertion library
/ Shared by both the convention-based runner (discover.q) and the BDD DSL
/ (dsl.q). An assertion either returns its actual value (so it can be
/ chained / returned as the test's result) or throws `.qt.AssertionFailed`
/ carrying a caught dictionary describing what failed, which runner.q
/ catches and turns into a `fail row.

\d .qt

/ thrown text is always this fixed tag; the real detail rides in .qt.lastFailure
ASSERT_TAG:"qtAssertionFailed";

lastFailure:`actual`expected`relation`msg!(::;::;::;"");

i.fail:{[actual;expected;relation;msg]
  lastFailure::`actual`expected`relation`msg!(actual;expected;relation;msg);
  '.qt.ASSERT_TAG;
 };

/ format a value for display in reports - keeps tables/dicts readable, caps huge output
i.fmt:{[x]
  s:.Q.s x;
  if[count[s]>400; s:(400#s),"...(truncated)"];
  s
 };

/ ---- core relation assertion ---------------------------------------------
/ assertThat[actual;relation;expected;msg] - relation is a binary function,
/ e.g. = < > <= >= like ~
assertThat:{[actual;relation;expected;msg]
  ok:.[relation;(actual;expected);{0b}];
  if[not ok; i.fail[actual;expected;relation;msg]];
  actual
 };

/ ---- equality, table-aware -------------------------------------------------
assertEquals:{[actual;expected;msg]
  if[actual~expected; :actual];
  if[.Q.qt expected;
    if[not (asc cols actual)~asc cols expected;
      i.fail[cols actual;cols expected;`sameCols;msg,": column mismatch"]];
    ];
  i.fail[actual;expected;`equals;msg]
 };

assertTrue:{[actual;msg]
  if[actual~1b; :actual];
  i.fail[actual;1b;`isTrue;msg]
 };

assertFalse:{[actual;msg]
  if[actual~0b; :actual];
  i.fail[actual;0b;`isFalse;msg]
 };

assertNull:{[actual;msg]
  if[all null actual; :actual];
  i.fail[actual;`null;`isNull;msg]
 };

/ protected apply, tagging success/failure unambiguously regardless of what
/ func itself returns: (1b;result) on success, (0b;errorText) on throw.
/ func is called as a unary function of arg (use (::) for a niladic func;
/ project multi-arg functions down to one remaining slot first, e.g.
/ .math.add[2;] to test with y fixed to 2).
i.papply:{[func;arg] @[{(1b;x y)}[func;];arg;{(0b;x)}]};

/ assertError[func;arg;msg] - func applied to arg (unary; see i.papply) and
/ must throw. Returns the caught error text.
/ assertErrorLike[likeGlob;func;arg;msg] also checks the error text matches a glob.
assertError:{[func;arg;msg]
  r:i.papply[func;arg];
  if[r 0; i.fail[r 1;`error;`throws;msg,": expected an error but got a result"]];
  r 1
 };

assertErrorLike:{[likeGlob;func;arg;msg]
  errText:.qt.assertError[func;arg;msg];
  if[not errText like likeGlob; i.fail[errText;likeGlob;`errorLike;msg,": error text didn't match"]];
  errText
 };

/ assertNoError[func;arg;msg] - inverse of assertError
assertNoError:{[func;arg;msg]
  r:i.papply[func;arg];
  if[not r 0; i.fail[r 1;`noError;`throws;msg,": ",r 1]];
  r 1
 };

/ assertClose[actual;expected;tolerance;msg] - numeric closeness
assertClose:{[actual;expected;tol;msg]
  d:abs actual-expected;
  if[d<=tol; :actual];
  i.fail[actual;expected;`close;msg,": |diff|=",string[d]," > tol=",string tol]
 };

/ multi-arg siblings of assertError/assertNoError: argList is applied via
/ `.` (splatting each positional arg), for functions of any real arity -
/ use these instead of assertError/assertNoError whenever func takes more
/ than one argument, or when you don't want to pre-project it down to
/ unary yourself. argList must be a genuine list matching func's arity
/ (enlist x for a single argument, same as func's own [x] declaration) -
/ a bare non-list value here hits the same '"type" that .[f;()] does for
/ a "niladic" call elsewhere in this library.
i.papplyN:{[func;argList] .[{[func;argList](1b;.[func;argList])};(func;argList);{(0b;x)}]};

assertErrorArgs:{[func;argList;msg]
  r:i.papplyN[func;argList];
  if[r 0; i.fail[r 1;`error;`throws;msg,": expected an error but got a result"]];
  r 1
 };

assertNoErrorArgs:{[func;argList;msg]
  r:i.papplyN[func;argList];
  if[not r 0; i.fail[r 1;`noError;`throws;msg,": ",r 1]];
  r 1
 };

fail:{[msg] i.fail[`fail;`fail;`fail;msg]};

\d .
