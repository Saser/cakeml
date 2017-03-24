open preamble
open backend_commonTheory

val _ = numLib.prefer_num();

val _ = new_theory "conLang"
val _ = set_grammar_ancestry ["ast", "finite_map", "sptree"]

(* Removes named datatype constructors. Follows modLang.
 *
 * The AST of conLang differs from modLang by using numbered tags instead of
 * constructor name identifiers for all data constructor patterns and
 * expressions. Constructors explicitly mention the type they are constructing.
 * Also type and exception declarations are removed.
 *)

val _ = Datatype`
 op =
  | Op (ast$op)
  | Init_global_var num`;

val _ = Datatype`
 pat =
  | Pvar varN
  | Plit lit
  | Pcon ((num # tid_or_exn)option) (pat list)
  | Pref pat`;

val _ = Datatype`
   exp =
  | Raise tra exp
  | Handle tra exp ((pat # exp) list)
  | Lit tra lit
  | Con tra ((num # tid_or_exn)option) (exp list)
  | Var_local tra varN
  | Var_global tra num
  | Fun tra varN exp
  | App tra op (exp list)
  | Mat tra exp ((pat # exp) list)
  | Let tra (varN option) exp exp
  | Letrec tra ((varN # varN # exp) list) exp
  | Extend_global tra num`;

val exp_size_def = definition"exp_size_def";

val exp6_size_APPEND = Q.store_thm("exp6_size_APPEND[simp]",
  `conLang$exp6_size (e ++ e2) = exp6_size e + exp6_size e2`,
  Induct_on`e`>>simp[exp_size_def])

val exp6_size_REVERSE = Q.store_thm("exp6_size_REVERSE[simp]",
  `conLang$exp6_size (REVERSE es) = exp6_size es`,
  Induct_on`es`>>simp[exp_size_def])

val _ = Datatype`
 dec =
  | Dlet num exp
  | Dletrec ((varN # varN # exp) list)`;

val _ = Datatype`
 prompt =
    Prompt (dec list)`;

val _ = Define `
  (num_defs [] = 0)
  ∧
  (num_defs (Dlet n _::ds) = (n + num_defs ds))
  ∧
  (num_defs (Dletrec funs::ds) = (LENGTH funs + num_defs ds))`;

(* for each type, for each arity, the number of constructors of that arity *)
val _ = type_abbrev( "exh_ctors_env" , ``:(modN,typeN) id |-> num spt``);

val _ = export_theory()
