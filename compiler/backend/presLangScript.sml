open preamble astTheory jsonTheory backend_commonTheory;
open conLangTheory modLangTheory exhLangTheory;

val _ = new_theory"presLang";

(*
* presLang is a presentation language, encompassing many intermediate languages
* of the compiler, adopting their constructors. The purpose of presLang is to be
* an intermediate representation between an intermediate language of the
* compiler and JSON. By translating an intermediate language to presLang, it can
* be given a JSON representation by calling pres_to_json on the presLang
* representation. presLang has no semantics, as it is never evaluated, and may
* therefore mix operators, declarations, patterns and expressions.
*)

(* Special operator wrapper for presLang *)
val _ = Datatype`
  op =
    | Ast_op ast$op
    | Conlang_op conLang$op`;

(* The format of a constructor, which differs by language. A Nothing constructor
* indicates a tuple pattern. *)
val _ = Datatype`
  conF =
    | Modlang_con (((modN, conN) id) option)
    | Conlang_con ((num # tid_or_exn) option)
    | Exhlang_con num`;

val _ = Datatype`
  exp =
    (* An entire program. Is divided into any number of top level prompts. *)
    | Prog (exp(*prompt*) list)
    | Prompt (modN option) (exp(*dec*) list)
    (* Declarations *)
    | Dlet num exp(*exp*)
    | Dletrec ((varN # varN # exp(*exp*)) list)
    | Dtype (modN list)
    | Dexn (modN list) conN (t list)
    (* Patterns *)
    | Pvar varN
    | Plit lit
    | Pcon conF (exp(*pat*) list)
    | Pref exp(*pat*)
    | Ptannot exp(*pat*) t
    (* Expressions *)
    | Raise tra exp
    | Handle tra exp ((exp(*pat*) # exp) list)
    | Var_local tra varN
    | Var_global tra num
    | Extend_global tra num (* Introduced in conLang *)
    | Lit tra lit
    | Con tra conF (exp list)
      (* Application of a primitive operator to arguments.
       Includes function application. *)
    | App tra op (exp list)
    | Fun tra varN exp
      (* Logical operations (and, or) *)
    | Log tra lop exp exp
    | If tra exp exp exp
      (* Pattern matching *)
    | Mat tra exp ((exp(*pat*) # exp) list)
      (* A let expression
         A Nothing value for the binding indicates that this is a
         sequencing expression, that is: (e1; e2). *)
    | Let tra (varN option) exp exp
      (* Local definition of (potentially) mutually recursive
         functions.
         The first varN is the function's name, and the second varN
         is its parameter. *)
    | Letrec tra ((varN # varN # exp) list) exp`;

(* Structured expression, an intermediate language between presLang and json, which strutcures the
* presLang expressions in tu suitable JSON format. *)
val _ = Datatype`
  sExp =
    | Tuple (sExp list)
    | Item (tra option) string (sExp list)
    | List (sExp list)`;

(* Functions for converting intermediate languages to presLang. *)

(* modLang *)

val mod_to_pres_pat_def = tDefine "mod_to_pres_pat"`
  mod_to_pres_pat p =
    case p of
       | ast$Pvar varN => presLang$Pvar varN
       | Plit lit => Plit lit
       | Pcon id pats => Pcon (Modlang_con id) (MAP mod_to_pres_pat pats)
       | Pref pat => Pref (mod_to_pres_pat pat)
       (* Won't happen, these are removed in compilation from source to mod. *)
       | Ptannot pat t => Ptannot (mod_to_pres_pat pat) t`
   cheat;

val mod_to_pres_exp_def = tDefine"mod_to_pres_exp"`
  (mod_to_pres_exp (modLang$Raise tra exp) = presLang$Raise tra (mod_to_pres_exp exp))
  /\
  (mod_to_pres_exp (Handle tra exp pes) =
    Handle tra (mod_to_pres_exp exp) (mod_to_pres_pes pes))
  /\
  (mod_to_pres_exp (Lit tra lit) = Lit tra lit)
  /\
  (mod_to_pres_exp (Con tra id_opt exps) = Con tra (Modlang_con id_opt) (MAP mod_to_pres_exp exps))
  /\
  (mod_to_pres_exp (Var_local tra varN) = Var_local tra varN)
  /\
  (mod_to_pres_exp (Var_global tra num) =  Var_global tra num)
  /\
  (mod_to_pres_exp (Fun tra varN exp) =  Fun tra varN (mod_to_pres_exp exp))
  /\
  (mod_to_pres_exp (App tra op exps) =  App tra (Ast_op op) (MAP mod_to_pres_exp exps))
  /\
  (mod_to_pres_exp (If tra exp1 exp2 exp3) =
    If tra (mod_to_pres_exp exp1) (mod_to_pres_exp exp2) (mod_to_pres_exp exp3))
  /\
  (mod_to_pres_exp (Mat tra exp pes) =
    Mat tra (mod_to_pres_exp exp) (mod_to_pres_pes pes))
  /\
  (mod_to_pres_exp (Let tra varN_opt exp1 exp2) =
    Let tra varN_opt (mod_to_pres_exp exp1) (mod_to_pres_exp exp2))
  /\
  (mod_to_pres_exp (Letrec tra funs exp) =
    Letrec tra
          (MAP (\(v1,v2,e).(v1,v2,mod_to_pres_exp e)) funs)
          (mod_to_pres_exp exp))
  /\
  (* Pattern-expression pairs *)
  (mod_to_pres_pes [] = [])
  /\
  (mod_to_pres_pes ((p,e)::pes) =
    (mod_to_pres_pat p, mod_to_pres_exp e)::mod_to_pres_pes pes)`
  cheat;

val mod_to_pres_dec_def = Define`
  mod_to_pres_dec d =
    case d of
       | modLang$Dlet num exp => presLang$Dlet num (mod_to_pres_exp exp)
       | Dletrec funs => Dletrec (MAP (\(v1,v2,e). (v1,v2,mod_to_pres_exp e)) funs)
       | Dtype mods type_def => Dtype mods
       | Dexn mods conN ts => Dexn mods conN ts`;

val mod_to_pres_prompt_def = Define`
  mod_to_pres_prompt (Prompt modN decs) =
    Prompt modN (MAP mod_to_pres_dec decs)`;

val mod_to_pres_def = Define`
  mod_to_pres prompts = Prog (MAP mod_to_pres_prompt prompts)`;

(* con_to_pres *)
val con_to_pres_pat_def = tDefine"con_to_pres_pat"`
  con_to_pres_pat p =
    case p of
       | conLang$Pvar varN => presLang$Pvar varN
       | Plit lit => Plit lit
       | Pcon opt ps => Pcon (Conlang_con opt) (MAP con_to_pres_pat ps)
       | Pref pat => Pref (con_to_pres_pat pat)`
    cheat;

val con_to_pres_exp_def = tDefine"con_to_pres_exp"`
  (con_to_pres_exp (conLang$Raise t e) = Raise t (con_to_pres_exp e))
  /\
  (con_to_pres_exp (Handle t e pes) = Handle t (con_to_pres_exp e) (con_to_pres_pes pes))
  /\
  (con_to_pres_exp (Lit t l) = Lit t l)
  /\
  (con_to_pres_exp (Con t ntOpt exps) = Con t (Conlang_con ntOpt) (MAP con_to_pres_exp exps))
  /\ 
  (con_to_pres_exp (Var_local t varN) = Var_local t varN)
  /\
  (con_to_pres_exp (Var_global t num) = Var_global t num)
  /\
  (con_to_pres_exp (Fun t varN e) = Fun t varN (con_to_pres_exp e))
  /\
  (con_to_pres_exp (App t op exps) = App t (Conlang_op op) (MAP con_to_pres_exp exps))
  /\
  (con_to_pres_exp (Mat t e pes) = Mat t (con_to_pres_exp e) (con_to_pres_pes pes))
  /\
  (con_to_pres_exp (Let t varN e1 e2) = Let t varN (con_to_pres_exp e1)
  (con_to_pres_exp e2))
  /\
  (con_to_pres_exp (Letrec t funs e) = Letrec t (MAP (\(v1,v2,e).(v1,v2,con_to_pres_exp e)) funs) (con_to_pres_exp e))
  /\
  (con_to_pres_exp (Extend_global t num) = Extend_global t num)
  /\
  (con_to_pres_pes [] = [])
  /\
  (con_to_pres_pes ((p,e)::pes) =
    (con_to_pres_pat p, con_to_pres_exp e)::con_to_pres_pes pes)`
  cheat;

val con_to_pres_dec_def = Define`
  con_to_pres_dec d =
    case d of
       | conLang$Dlet num exp => presLang$Dlet num (con_to_pres_exp exp)
       | Dletrec funs => Dletrec (MAP (\(v1,v2,e). (v1,v2,con_to_pres_exp e)) funs)`;

val con_to_pres_prompt_def = Define`
  con_to_pres_prompt (Prompt decs) = Prompt NONE (MAP con_to_pres_dec decs)`;

val con_to_pres_def = Define`
  con_to_pres prompts = Prog (MAP con_to_pres_prompt prompts)`;

(* exh_to_pres *)
val exh_to_pres_pat_def = tDefine"exh_to_pres_pat"`
  exh_to_pres_pat p =
    case p of
       | exhLang$Pvar varN => presLang$Pvar varN
       | Plit lit => Plit lit
       | Pcon num ps => Pcon (Exhlang_con num) (MAP exh_to_pres_pat ps)
       | Pref pat => Pref (exh_to_pres_pat pat)`
    cheat;

val exh_to_pres_exp_def = tDefine"exh_to_pres_exp"` 
  (exh_to_pres_exp (exhLang$Raise t e) = Raise t (exh_to_pres_exp e)) 
  /\
  (exh_to_pres_exp (Handle t e pes) = Handle t (exh_to_pres_exp e) (exh_to_pres_pes pes))
  /\
  (exh_to_pres_exp (Lit t l) = Lit t l)
  /\
  (exh_to_pres_exp (Con t n es) = Con t (Exhlang_con n) (MAP exh_to_pres_exp es))
  /\
  (exh_to_pres_exp (Var_local t varN) = Var_local t varN)
  /\
  (exh_to_pres_exp (Var_global t n) = Var_global t n)
  /\
  (exh_to_pres_exp (Fun t varN e) = Fun t varN (exh_to_pres_exp e))
  /\
  (exh_to_pres_exp (App t op es) = App t (Conlang_op op) (MAP exh_to_pres_exp es))
  /\ 
  (exh_to_pres_exp (Mat t e pes) = Mat t (exh_to_pres_exp e) (exh_to_pres_pes pes)) 
  /\
  (exh_to_pres_exp (Let t varN e1 e2) = Let t varN (exh_to_pres_exp e1) (exh_to_pres_exp e2)) 
  /\
  (exh_to_pres_exp (Letrec t funs e1) = Letrec t (MAP (\(v1,v2,e).(v1,v2,exh_to_pres_exp e)) funs) (exh_to_pres_exp e1))
  /\
  (exh_to_pres_exp (Extend_global t n) = Extend_global t n)
  /\
  (exh_to_pres_pes [] = [])
  /\
  (exh_to_pres_pes ((p,e)::pes) =
    (exh_to_pres_pat p, exh_to_pres_exp e)::exh_to_pres_pes pes)`
  cheat; 

(* structured_to_json *)
(* TODO: Add words *)

val new_obj_def = Define`
  new_obj cons fields = Object (("name", String cons)::fields)`;

val lit_to_value_def = Define`
  (lit_to_value (IntLit i) = Int i)
  /\
  (lit_to_value (Char c) = String [c])
  /\
  (lit_to_value (StrLit s) = String s)
  /\
  (lit_to_value _ = String "word8/64")`;

val num_to_json_def = Define`
  num_to_json n = String (num_to_str n)`;

val trace_to_json_def = Define`
  (trace_to_json (backend_common$Cons tra num) =
    Object [("name", String "Cons"); ("num", num_to_json num); ("trace", trace_to_json tra)])
  /\
  (trace_to_json (Union tra1 tra2) =
      Object [("name", String "Union"); ("trace1", trace_to_json tra1); ("trace2", trace_to_json tra2)])
  /\
  (trace_to_json Empty = Object [("name", String "Empty")])
  /\
  (* TODO: cancel entire trace when None, or verify that None will always be at
  * the top level of a trace. *)
  (trace_to_json None = Null)`;

val word_size_to_json_def = Define`
  (word_size_to_json W8 = new_obj "W8" [])
  /\
  (word_size_to_json W64 = new_obj "W64" [])`;

val opn_to_json_def = Define`
  (opn_to_json Plus = new_obj "Plus" [])
  /\
  (opn_to_json Minus = new_obj "Minus" [])
  /\
  (opn_to_json Times = new_obj "Times" [])
  /\
  (opn_to_json Divide = new_obj "Divide" [])
  /\
  (opn_to_json Modulo = new_obj "Modulo" [])`;

val opb_to_json_def = Define`
  (opb_to_json Lt = new_obj "Lt" [])
  /\
  (opb_to_json Gt = new_obj "Gt" [])
  /\
  (opb_to_json Leq = new_obj "Leq" [])
  /\
  (opb_to_json Geq = new_obj "Geq" [])`;

val opw_to_json_def = Define`
  (opw_to_json Andw = new_obj "Andw" [])
  /\
  (opw_to_json Orw = new_obj "Orw" [])
  /\
  (opw_to_json Xor = new_obj "Xor" [])
  /\
  (opw_to_json Add = new_obj "Add" [])
  /\
  (opw_to_json Sub = new_obj "Sub" [])`;

val shift_to_json_def = Define`
  (shift_to_json Lsl = new_obj "Lsl" [])
  /\
  (shift_to_json Lsr = new_obj "Lsr" [])
  /\
  (shift_to_json Asr = new_obj "Asr" [])
  /\
  (shift_to_json Ror = new_obj "Ror" [])`;

(* TODO: pres_to_structured uses `op_to_structured`. Implement that. *)
val op_to_json_def = Define`
  (op_to_json (Conlang_op (Init_global_var num)) = new_obj "Init_global_var" [("num", num_to_json num)])
  /\
  (op_to_json (Conlang_op (Op astop)) = new_obj "Op" [("op", op_to_json (Ast_op (astop)))])
  /\
  (op_to_json (Ast_op (Opn opn)) = new_obj "Opn" [("opn", opn_to_json opn)])
  /\
  (op_to_json (Ast_op (Opb opb)) = new_obj "Opb" [("opb", opb_to_json opb)])
  /\
  (op_to_json (Ast_op (Opw word_size opw)) = new_obj "Opw" [
    ("word_size", word_size_to_json word_size);
    ("opw", opw_to_json opw)
  ])
  /\
  (op_to_json (Ast_op (Shift word_size shift num)) = new_obj "Shift" [
    ("word_size", word_size_to_json word_size);
    ("shift", shift_to_json shift);
    ("num", num_to_json num)
  ])
  /\
  (op_to_json (Ast_op Equality) = new_obj "Equality" [])
  /\
  (op_to_json (Ast_op Opapp) = new_obj "Opapp" [])
  /\
  (op_to_json (Ast_op Opassign) = new_obj "Opassign" [])
  /\
  (op_to_json (Ast_op Oprep) = new_obj "Oprep" [])
  /\
  (op_to_json (Ast_op Opderep) = new_obj "Opderep" [])
  /\
  (op_to_json (Ast_op Aw8alloc) = new_obj "Aw8alloc" [])
  /\
  (op_to_json (Ast_op Aw8sub) = new_obj "Aw8sub" [])
  /\
  (op_to_json (Ast_op Aw8length) = new_obj "Aw8length" [])
  /\
  (op_to_json (Ast_op Aw8update) = new_obj "Aw8update" [])
  /\
  (op_to_json (Ast_op (WordFromInt word_size)) = new_obj "WordFromInt" [
    ("word_size", word_size_to_json word_size)
  ])
  /\
  (op_to_json (Ast_op (WordToInt word_size)) = new_obj "WordToInt" [
    ("word_size", word_size_to_json word_size)
  ])
  /\
  (op_to_json (Ast_op Ord) = new_obj "Ord" [])
  /\
  (op_to_json (Ast_op Chr) = new_obj "Chr" [])
  /\
  (op_to_json (Ast_op (Chopb opb)) = new_obj "Chopb" [("opb", opb_to_json opb)])
  /\
  (op_to_json (Ast_op Implode) = new_obj "Implode" [])
  /\
  (op_to_json (Ast_op Strsub) = new_obj "Strsub" [])
  /\
  (op_to_json (Ast_op Strlen) = new_obj "Strlen" [])
  /\
  (op_to_json (Ast_op VfromList) = new_obj "VfromList" [])
  /\
  (op_to_json (Ast_op Vsub) = new_obj "Vsub" [])
  /\
  (op_to_json (Ast_op Vlength) = new_obj "Vlength" [])
  /\
  (op_to_json (Ast_op Aalloc) = new_obj "Aalloc" [])
  /\
  (op_to_json (Ast_op Asub) = new_obj "Asub" [])
  /\
  (op_to_json (Ast_op Alength) = new_obj "Alength" [])
  /\
  (op_to_json (Ast_op Aupdate) = new_obj "Aupdate" [])
  /\
  (op_to_json (Ast_op (FFI str)) = new_obj "FFI" [("str", String str)])
  /\
  (op_to_json _ = new_obj "Unknown" [])`;

(* TODO: Change to lop_to_structured. *)
val lop_to_json_def = Define`
  (lop_to_json ast$And = String "And")
  /\
  (lop_to_json Or = String "Or")
  /\
  (lop_to_json _ = String "Unknown")`

val id_to_list_def = Define`
  id_to_list i = case i of
                      | Long modN i' => modN::id_to_list i'
                      | Short conN => [conN]`;

val num_to_hex_digit_def = Define `
  num_to_hex_digit n =
    if n < 10 then [CHR (48 + n)] else
    if n < 16 then [CHR (55 + n)] else []`;

val num_to_hex_def = Define `
  num_to_hex n =
    (if n < 16 then [] else num_to_hex (n DIV 16)) ++
    num_to_hex_digit (n MOD 16)`;

val word_to_hex_string_def = Define `
  word_to_hex_string w = "0x" ++ num_to_hex (w2n (w:'a word))`;

(* TODO: Change to lit_to_structured *)
val lit_to_json_def = Define`
  (lit_to_json (IntLit i) = new_obj "IntLit" [("value", Int i)])
  /\
  (lit_to_json (Char c) = new_obj "Char" [("value", String [c])])
  /\
  (lit_to_json (StrLit s) = new_obj "StrLit" [("value", String s)])
  /\
  (lit_to_json (Word8 w) = new_obj "Word8" [("value", String (word_to_hex_string w))])
  /\
  (lit_to_json (Word64 w) = new_obj "Word64" [("value",  String (word_to_hex_string w))])`

(* Converts a structured expression to JSON *)
val structured_to_json_def = tDefine"structured_to_json"`
  (structured_to_json (Tuple es) =
    let es' = MAP structured_to_json es in
      Object [("isTuple", Bool T); ("elements", Array es')])
  /\
  (structured_to_json (Item tra name es) =
    let es' = MAP structured_to_json es in
    let props = [("name", String name); ("args", Array es')] in
    let props' = case tra of
                   | NONE => props
                   | SOME t => ("trace", trace_to_json t)::props in
      Object props')
   /\
   (structured_to_json (List es) = Array (MAP structured_to_json es))`
      cheat;

(* Helpers for converting pres to structured. *)
val string_to_structured_def = Define`
  string_to_structured s = Item NONE s []`;

val num_to_structured_def = Define`
  num_to_structured n = string_to_structured (num_to_str n)`;

val option_string_to_structured_def = Define`
  (option_string_to_structured opt = case opt of
                      | NONE => Item NONE "NONE" []
                      | SOME opt' => string_to_structured opt')`

val id_to_structured_def = Define`
    id_to_structured ids = List (MAP string_to_structured (id_to_list ids))`

val tctor_to_structured_def = Define`
  (tctor_to_structured (ast$TC_name ids) =
    let ids' = id_to_structured ids in
      Item NONE "TC_name" [ids'])
  /\
  (tctor_to_structured TC_int = string_to_structured "TC_int")
  /\
  (tctor_to_structured TC_char = string_to_structured "TC_char")
  /\
  (tctor_to_structured TC_string = string_to_structured "TC_string")
  /\
  (tctor_to_structured TC_ref = string_to_structured "TC_ref")
  /\
  (tctor_to_structured TC_word8 = string_to_structured "TC_word8")
  /\
  (tctor_to_structured TC_word64 = string_to_structured "TC_word64")
  /\
  (tctor_to_structured TC_word8array = string_to_structured "TC_word8array")
  /\
  (tctor_to_structured TC_fn = string_to_structured "TC_fn")
  /\
  (tctor_to_structured TC_tup = string_to_structured "TC_tup")
  /\
  (tctor_to_structured TC_exn = string_to_structured "TC_exp")
  /\
  (tctor_to_structured TC_vector = string_to_structured "TC_vector")
  /\
  (tctor_to_structured TC_array = string_to_structured "TC_array")`

val num_to_structured_def = Define`
  num_to_structured n = Item NONE (num_to_str n) []`;

val t_to_structured_def = tDefine"t_to_json"`
  (t_to_structured (Tvar tvarN) = Item NONE "Tvar" [string_to_structured tvarN])
  /\
  (t_to_structured (Tvar_db n) = Item NONE "Tvar_db" [num_to_structured n])
  /\
  (t_to_structured (Tapp ts tctor) = Item NONE "Tapp" [ List (MAP t_to_structured ts);
    tctor_to_structured tctor])`
  cheat;

val tid_or_exn_to_structured_def = Define`
  tid_or_exn_to_structured te =
   let (name, id) =
     case te of
       | TypeId id =>  ("TypeId", id)
       | TypeExn id => ("TypeExn", id) in
     Item NONE name [id_to_structured id]`;

val conf_to_structured_def = Define`
  conf_to_structured con =
    let none = Item NONE "NONE" [] in
      case con of
         | Modlang_con NONE => none
         | Conlang_con NONE => none
         | Modlang_con (SOME id) => Item NONE "SOME" [id_to_structured id]
         | Conlang_con (SOME (n,t)) => Item NONE "SOME" [Tuple [num_to_structured
         n; tid_or_exn_to_structured t]]
         | Exhlang_con c => Item NONE "SOME" [num_to_structured c]`;

(* Takes a presLang$exp and produces json$obj that mimics its structure. *)
val pres_to_structured_def = tDefine"pres_to_structured"`
  (* Top level *)
  (pres_to_structured (presLang$Prog tops) =
    let tops' = List (MAP pres_to_structured tops) in
      Item NONE "Prog" [tops'])
  /\
  (pres_to_structured (Prompt modN decs) =
    let decs' = List (MAP pres_to_structured decs) in
    let modN' = option_string_to_structured modN in
      Item NONE "Prompt" [modN'; decs'])
  /\
  (pres_to_structured (Dlet num exp) =
      Item NONE "Dlet" [num_to_structured num; pres_to_structured exp])
  /\
  (pres_to_structured (Dletrec lst) =
    let fields = List (MAP (\ (v1, v2, exp) . Tuple [string_to_structured v1; string_to_structured v2; pres_to_structured exp]) lst) in
      Item NONE "Dletrec" [fields] )
  /\
  (pres_to_structured (Dtype modNs) =
    let modNs' = List (MAP string_to_structured modNs) in
      Item NONE "Dtype" [modNs'])
  /\
  (pres_to_structured (Dexn modNs conN ts) =
    let modNs' = List (MAP string_to_structured modNs) in
    let ts' = List (MAP t_to_structured ts) in
      Item NONE "Dexn" [modNs'; string_to_structured conN;  ts'])
  /\
  (pres_to_structured (Pvar varN) =
      Item NONE "Pvar" [string_to_structured varN])
  /\
  (pres_to_structured (Plit lit) =
      Item NONE "Plit" [lit_to_structured lit])
  /\
  (pres_to_structured (Pcon conF exps) =
    let exps' = List (MAP pres_to_structured exps) in
      Item NONE "Pcon" [conf_to_structured conF; exps'])
  /\
  (pres_to_structured (Pref exp) =
      Item NONE "Pref" [pres_to_structured exp])
  /\
  (pres_to_structured (Ptannot exp t) =
      Item NONE "Ptannot" [pres_to_structured exp; t_to_structured t])
  /\
  (pres_to_structured (Raise tra exp) =
      Item (SOME tra) "Raise" [pres_to_structured exp])
  /\
  (pres_to_structured (Handle tra exp expsTup) =
    let expsTup' = List (MAP (\(e1, e2) . Tuple [ pres_to_structured e1; pres_to_structured e2 ]) expsTup) in
      Item (SOME tra) "Handle" [pres_to_structured exp; expsTup'])
  /\
  (pres_to_structured (Var_local tra varN) =
      Item (SOME tra) "Var_local" [string_to_structured varN])
  /\
  (pres_to_structured (Var_global tra num) =
      Item (SOME tra) "Var_global" [num_to_structured num])
  /\
  (pres_to_structured (Extend_global tra num) =
      Item (SOME tra) "Extend_global" [num_to_structured num])
  /\
  (pres_to_structured (Lit tra lit) =
      Item (SOME tra) "Lit" [lit_to_structured lit])
  /\
  (pres_to_structured (Con tra conF exps) =
    let exps' = List (MAP pres_to_structured exps) in
      Item (SOME tra) "Pcon" [conf_to_structured conF; exps'])
  /\
  (pres_to_structured (App tra op exps) =
    let exps' = List (MAP pres_to_structured exps) in
      Item (SOME tra) "App" [op_to_structured op; exps'])
  /\
  (pres_to_structured (Fun tra varN exp) =
      Item (SOME tra) "Fun" [string_to_structured varN; pres_to_structured exp])
  /\
  (pres_to_structured (Log tra lop exp1 exp2) =
      Item (SOME tra) "Log" [lop_to_structured lop; pres_to_structured exp1; pres_to_structured exp2])
  /\
  (pres_to_structured (If tra exp1 exp2 exp3) =
      Item (SOME tra) "If" [pres_to_structured exp1; pres_to_structured exp2; pres_to_structured exp3])
  /\
  (pres_to_structured (Mat tra exp expsTup) =
    let expsTup' = List (MAP (\(e1, e2) . Tuple [ pres_to_structured e1; pres_to_structured e2 ]) expsTup) in
      Item (SOME tra) "Mat" [pres_to_structured exp; expsTup'])
  /\
  (pres_to_structured (Let tra varN exp1 exp2) =
    let varN' = option_string_to_structured varN in
      Item (SOME tra) "Let" [varN'; pres_to_structured exp1; pres_to_structured exp2])
  /\
  (pres_to_structured (Letrec tra varexpTup exp) =
    let varexpTup' = List (MAP (\ (v1, v2, e) . Tuple [
      string_to_structured v1;
      string_to_structured v2;
      pres_to_structured e
    ]) varexpTup) in
      Item (SOME tra) "Letrec" [varexpTup'; pres_to_structured exp])
  /\
  (pres_to_structured _ = Item NONE "\"Unknown constructor\"" [])
  `cheat;

(* Function to construct general functions from a language to JSON. Call with
* the name of the language and what fucntion to use to convert it to preslang to
* obtain a function which takes a program in an intermediate language and
* returns a JSON representation of that program. *)
(* TODO: Make these use the pres_to_structured step. *)
val lang_to_json_def = Define`
  lang_to_json langN func = 
    \ p . Object [
      ("lang", String langN);
      ("prog", structured_to_json (pres_to_structured (func p)))]`;

val mod_to_json_def = Define`
  mod_to_json = lang_to_json "modLang" mod_to_pres`;

val con_to_json_def = Define`
  con_to_json = lang_to_json "conLang" con_to_pres`;

(* decLang uses the same structure as conLang, but the compilation step from con
* to dec returns an expression rather than a prompt. *)
val dec_to_json_def = Define`
  dec_to_json = lang_to_json "decLang" con_to_pres_exp`;

val exh_to_json_def = Define`
  exh_to_json = lang_to_json "exhLang" exh_to_pres_exp`;

val _ = export_theory();
