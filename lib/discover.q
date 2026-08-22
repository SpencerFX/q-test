/ q-test :: convention-based discovery
/ Scans a namespace for functions by naming convention, à la qunit:
/   test*          - a test (arity 0, no args)
/   setUp*         - run before EVERY test in the namespace
/   tearDown*      - run after EVERY test in the namespace
/   beforeAll*     - run ONCE before any test (namespace fixture)
/   afterAll*      - run ONCE after all tests (namespace fixture)
/   parameters     - if present, returns a list of parameter values; the
/                     whole namespace (beforeAll..afterAll) is run once per
/                     parameter value, with that value bound to `parameter`
/                     in the namespace before each run.
/ Any of these may be absent. Order among same-prefix functions is
/ alphabetical (q dict key order), not declaration order.

\d .qt

/ names (as symbols, unqualified) directly under a namespace matching a
/ glob, restricted to actual callable functions (skips plain data that
/ happens to share the naming convention, e.g. a `testConfig` dict)
i.namesLike:{[ns;pat]
  names:key[ns] where key[ns] like pat;
  names where {(type get ` sv x,y) within 100 112h}[ns] each names
 };

i.qualify:{[ns;n] ` sv ns,n};

/ discover.byPrefix[ns] -> dict of category->list of qualified function names
discover.byPrefix:{[ns]
  `test`setUp`tearDown`beforeAll`afterAll!{[ns;pat] asc i.qualify[ns] each i.namesLike[ns;pat]}[ns] each ("test*";"setUp*";"tearDown*";"beforeAll*";"afterAll*")
 };

/ does this namespace declare a `parameters` function?
discover.hasParameters:{[ns] `parameters in key ns};

\d .
