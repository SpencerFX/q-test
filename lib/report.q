/ q-test :: reporting - console summary and JUnit XML export, both reading
/ the one shared .qt.results schema produced by runner.q/dsl.q alike.

\d .qt

/ ---- console ---------------------------------------------------------------
report.i.counts:{[t]
  `pass`fail`error`skip`pending!{[t;x] sum t[`status]=x}[t] each `pass`fail`error`skip`pending
 };

report.summary:{
  t:results;
  c:report.i.counts[t];
  totalTime:sum t`time;
  -1 "";
  -1 "q-test summary: ",string[count t]," total  ",
    string[c`pass]," passed  ",
    string[c`fail]," failed  ",
    string[c`error]," errored  ",
    string[c`skip]," skipped  ",
    string[c`pending]," pending  (",string[totalTime],"ms)";
  if[0<c[`fail]+c`error;
    -1 "";
    -1 "Failures / errors:";
    {[t;i] row:t i; -1 "  [",string[row`status],"] ",string[row`name],": ",row`msg}[t] each where t[`status] in `fail`error;
   ];
  -1 "";
  0=c[`fail]+c`error
 };

report.console:{
  0!select status,name,time,mem,msg from results
 };

/ ---- JUnit XML --------------------------------------------------------------
report.i.esc:{[s]
  s:ssr[s;"&";"&amp;"];
  s:ssr[s;"<";"&lt;"];
  s:ssr[s;">";"&gt;"];
  s:ssr[s;"\"";"&quot;"];
  s
 };

report.i.caseXml:{[row]
  nm:report.i.esc string row`name;
  tm:string (row`time)%1000f;
  body:$[row[`status]=`pass; "";
    row[`status]=`skip; "<skipped/>";
    row[`status]=`pending; "<skipped message=\"pending\"/>";
    row[`status]=`fail; "<failure message=\"",(report.i.esc row`msg),"\"/>";
    "<error message=\"",(report.i.esc row`msg),"\"/>"];
  "  <testcase name=\"",nm,"\" time=\"",tm,"\">",body,"</testcase>"
 };

/ writes a JUnit-format XML report of .qt.results to the given file path
/ (a symbol, e.g. `:reports/junit.xml)
report.junit:{[path]
  t:results;
  c:report.i.counts[t];
  header:"<testsuite name=\"q-test\" tests=\"",string[count t],
    "\" failures=\"",string[c`fail],
    "\" errors=\"",string[c`error],
    "\" skipped=\"",string[c[`skip]+c`pending],
    "\" time=\"",(string (sum t`time)%1000f),"\">";
  lines:("<?xml version=\"1.0\" encoding=\"UTF-8\"?>";header);
  lines,:report.i.caseXml each t;
  lines,:enlist "</testsuite>";
  path 0: lines;
  path
 };

\d .
