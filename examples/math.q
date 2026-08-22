/ example source module under test
\d .math

add:{x+y};
sub:{x-y};
getPrimesLessThan:{$[x<4;enlist 2;r,1_where not any x#'not til each r:.z.s ceiling sqrt x]};

\d .
