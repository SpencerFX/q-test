/ q-test :: lightweight property-based testing
/ forAll[gens;prop;msg] draws `trials` random argument tuples from a list
/ of generators, applies prop to each, and requires it to return 1b every
/ time. On failure it shrinks the failing case toward something simpler
/ (smaller numbers, shorter lists, closer to a "zero" value) before
/ reporting, and prints a replay seed so the exact case can be reproduced.
/ -
/ Unlike q-desc's file-level fuzzer (which infers argument types from
/ //@param comments), generators here are just plain values you compose
/ explicitly - no annotation step, and they work standalone as an
/ assertion, not only against whole files.
/ (a lone "/" on its own line would start a block comment in q - avoid it)

/ NOTE: this q build's \d cannot jump directly into an unset *nested*
/ namespace (\d .qt.gen fails if .qt.gen doesn't already exist, even when
/ .qt does) - so, same as .qt.i.* elsewhere, everything here is reached by
/ staying under \d .qt and using a gen.* / gen.i.* prefix instead.
\d .qt

gen.trials:100;
gen.maxShrinks:200;

/ ---- built-in generators ---------------------------------------------
/ A generator is a value that, applied to one argument (any argument -
/ forAll always calls it as g[(::)]), draws one fresh random value. The
/ constructors below (gen.int, gen.float, gen.sym, ...) are configured
/ with their range/pool up front and return that callable; the extra
/ unfilled slot is what forAll's later g[(::)] fills in to actually draw.
gen.i.int:{[lo;hi;d] lo+rand 1+hi-lo};
gen.i.float:{[lo;hi;d] lo+(hi-lo)*rand 1f};
gen.i.bool:{[d] rand 0b};
gen.i.sym:{[pool;d] pool rand count pool};
gen.i.str:{[maxLen;d] .Q.a rand each 1+til 1+rand maxLen};
gen.i.listOf:{[g;maxLen;d] g[(::)] each til 1+rand maxLen};
gen.i.oneOf:{[choices;d] choices rand count choices};

gen.int:{[lo;hi] gen.i.int[lo;hi;]};
gen.float:{[lo;hi] gen.i.float[lo;hi;]};
gen.bool:gen.i.bool;
gen.sym:{[pool] gen.i.sym[pool;]};
gen.str:{[maxLen] gen.i.str[maxLen;]};
gen.listOf:{[g;maxLen] gen.i.listOf[g;maxLen;]};
gen.oneOf:{[choices] gen.i.oneOf[choices;]};

/ ---- shrinking ----------------------------------------------------------
/ shrink candidates for one value, nearer to a "simplest" version of it.
/ numeric: halve the distance to 0. list: drop elements. else: no shrink.
gen.i.candidates:{[v]
  $[(type v) in -7 -6 -5h; distinct 0,v,`long$v%2;
    (type v) in -9 -8h;    distinct 0,v,v%2;
    0h=type v;             $[0=count v;();(1_v;-1_v)];
    ()]
 };

/ shrink one argument tuple: try shrinking each position in turn, keep the
/ smallest change that still fails `prop`, stop after maxShrinks attempts
gen.i.shrink:{[prop;args]
  best:args; budget:gen.maxShrinks;
  i:0;
  while[(i<count best) and budget>0;
    cands:gen.i.candidates best[i];
    found:0b;
    j:0;
    while[(not found) and (j<count cands) and budget>0;
      trial:@[best;i;:;cands j];
      budget-:1;
      ok:.[{1b~.[x;y]}[prop];enlist trial;{0b}];  / treat errors as "still fails"
      if[not ok; best:trial; found:1b];
      j+:1;
     ];
    i:$[found;0;i+1];  / restart shrinking from position 0 after any success
   ];
  best
 };

/ ---- the public entry point ----------------------------------------------
/ forAll[gens;prop;msg]
/   gens - list of generator functions (see above), one per argument
/   prop - function of (count gens) args returning a boolean
/ Throws via .qt.i.fail (same as any other assertion) with the shrunk
/ counterexample and a replay seed in the message on failure.
gen.forAll:{[gens;prop;msg]
  / (aGenerator) with no trailing ";" is just aGenerator itself in q, not a
  / 1-element list containing it - a single-generator call written that way
  / would otherwise silently iterate over the generator's own internals
  / instead of calling it once. Normalize here so callers don't need to
  / remember `enlist` for the single-argument case.
  gens:$[(type gens) within 100 112h; enlist gens; gens];
  seed:`int$.z.p;
  system "S ",string 0W & abs seed;
  failing:0N;
  i:0;
  while[(i<gen.trials) and (0N~failing);
    args:gens@\:();
    ok:.[{1b~.[x;y]}[prop];enlist args;{0b}];
    if[not ok; failing:args];
    i+:1;
   ];
  if[not (0N)~failing;
    shrunk:gen.i.shrink[prop;failing];
    i.fail[shrunk;`holds;`forAll;
      msg,": failed after ",string[i]," trial(s), shrunk counterexample=",
      i.fmt[shrunk],", replay with system \"S ",string[seed],"\""];
   ];
  (::)
 };

\d .
