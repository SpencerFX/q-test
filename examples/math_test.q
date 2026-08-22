/ convention-based style: functions named test* are auto-discovered, no
/ registration boilerplate beyond .qt.register at the bottom.
system "l examples/math.q";

\d .mathTest

testAdd:{.qt.assertEquals[.math.add[2;2];4;"2+2=4"]};
testSub:{.qt.assertEquals[.math.sub[2;2];0;"2-2=0"]};
testAddSymbolErrors:{.qt.assertError[.math.add[2;];`two;"cannot add a symbol"]};
testPrimesLessThanTen:{.qt.assertEquals[.math.getPrimesLessThan[10];2 3 5 7;"primes < 10"]};

/ property-based: no hand-picked example needed, forAll draws 100 trials
testAddCommutes:{
  .qt.gen.forAll[(.qt.gen.int[-1000;1000];.qt.gen.int[-1000;1000]);
    {[a;b] .math.add[a;b] = .math.add[b;a]};
    "add is commutative"]
 };

\d .
.qt.register[`.mathTest];
