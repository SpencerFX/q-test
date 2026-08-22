/ q-test :: auto-restoring mock framework
/ mock[name;value] replaces a global (function or variable) and remembers
/ its previous value (or the fact that it didn't exist). .qt.restore[]
/ puts everything back exactly as it was. Call restore[] from a
/ tearDown*/afterEach so mutation from one test never leaks into the next.

\d .qt

i.mockStore:(1#`)!1#(::);   / name -> original value, for names that existed
i.mockCreated:`symbol$();  / names that did NOT exist before mocking (fully delete on restore)

/ mock[name;newVal] - name is a symbol exactly as you'd reference the
/ variable: `add for a bare top-level global, `.math.add for a namespaced
/ one. Existing value is saved on first mock of that name; a second mock of
/ the same name in the same test does not clobber the originally-saved value.
mock:{[name;newVal]
  exists:not `qtNoSuchVar~ @[get;name;`qtNoSuchVar];
  if[not (name in key i.mockStore) or (name in i.mockCreated);
    $[exists;
      i.mockStore[name]:get name;
      i.mockCreated,:name]];
  name set newVal;
  name
 };

/ q cannot truly remove anything that lives directly in root - a bare
/ top-level name (`foo) or a single-segment dotted one (`.foo) - once
/ defined; the best available there is clearing it to (::). A name nested
/ at least two levels deep (`.ns.foo) can genuinely be dropped from its
/ namespace via functional delete.
i.uncreate:{[name]
  parts:` vs name;
  ns:$[1=count parts; `; ` sv -1_parts];
  $[ns~`; name set (::); ![ns;();0b;enlist last parts]]
 };

/ restore[] - put every mocked name back to its pre-mock value, and remove
/ any name that mock[] itself created from nothing.
restore:{
  saved:(key[i.mockStore] except `)#i.mockStore;  / drop the init placeholder key
  if[count saved;
    {x set y}'[key saved; value saved];
    ];
  i.uncreate each i.mockCreated;
  i.mockStore::(1#`)!1#(::);
  i.mockCreated::`symbol$();
 };

\d .
