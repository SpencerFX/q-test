/ BDD style: describe/should, with mocking and hooks. Runs immediately when
/ this file loads - no separate registration step.
\d .stack
push:{[s;v] s,v};
pop:{[s] -1_s};
top:{[s] last s};
\d .

.qt.describe["Stack #fast"]{
  .qt.before{`.stack.s set ()};

  .qt.should["push adds an element"]{
    .stack.s:.stack.push[.stack.s;1];
    (count .stack.s) ~ 1
   };

  .qt.should["pop removes the last element"]{
    .stack.s:.stack.push[.stack.push[.stack.s;1];2];
    .stack.s:.stack.pop[.stack.s];
    .stack.s ~ enlist 1
   };

  .qt.should["top returns without removing"]{
    .stack.s:.stack.push[.stack.s;42];
    .qt.assertEquals[.stack.top[.stack.s];42;"top is 42"];
    .qt.assertEquals[count .stack.s;1;"still one element"]
   };

  .qt.skip["not implemented: peek at depth n"]{1b};
 };
