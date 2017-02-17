val to_json_def = tDefine"to_json"`
  (to_json (Raise t e) =
   Object [("cons", String "Raise");("tra", Null); ("exp", to_json e)])
  /\
  (to_json (Lit t l) =
   Object [("cons", String "Lit");("tra", Null); ("value", lit_to_value l)])`
   cheat;

val lit_to_value_def = tDefine"lit_to_value"`
  (lit_to_value (IntLit i) = Int i) 
  /\
  (lit_to_value (Char c) = String (c::""))
  /\
  (lit_to_value (StrLit s) = String s)`
  cheat;

EVAL ``to_json (Raise t (Lit t (IntLit 5)))``;
EVAL ``to_json (Raise t (Lit t (Char x)))``;
EVAL ``to_json (Raise t (Lit t (StrLit "jsonteststring")))``;
EVAL ``lit_to_value (StrLit "din moder")``;
