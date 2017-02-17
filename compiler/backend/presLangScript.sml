open preamble astTheory jsonTheory;

val _ = new_theory"presLang";

(* 
* presLang is a presentation language, encompassing many intermediate languages
* of the compiler, adopting their constructors. The purpose of presLang is to be
* an intermediate representation between an intermediate language of the
* compiler and JSON. By translating an intermediate language to presLang, it can
* be given a JSON representation by calling to_json on the presLang
* representation. presLang has no semantics, as it is never evaluated, and may
* therefore mix operators, declarations, patterns and expressions.
*)

val _ = Datatype`
  exp =
    | Top (exp list)
    | Tdec (modN option) (specs option) exp
    | Dec
    | Empty`;

val to_json_def = tDefine "to_json"`
  to_json _ = json$Null`
  cheat;

val _ = export_theory();
