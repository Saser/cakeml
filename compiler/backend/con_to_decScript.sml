open preamble conLangTheory
open backend_commonTheory

val _ = new_theory"con_to_dec"

(* The translator to decLang maps a declaration to an expression that sets of
 * the global environment in the right way. If evaluating the expression
 * results in an exception, then the exception is handled, and a SOME
 * containing the exception is returned. Otherwise, a NONE is returned.
 *)

val _ = Define`
  (init_globals tra tidx [] idx =
   Con (mk_cons tra tidx) NONE [])
  ∧
  (init_globals tra tidx (x::vars) idx =
   Let (mk_cons tra tidx) NONE (App (mk_cons tra (tidx+1)) (Init_global_var idx)
   [Var_local (mk_cons tra (tidx+2)) x]) (init_globals tra (tidx+3) vars (idx+1)))`;


val _ = Define `
  (init_global_funs tra tidx next [] = Con (mk_cons tra tidx) NONE [])
  ∧
  (init_global_funs tra tidx next ((f,x,e)::funs) =
   Let (mk_cons tra tidx) NONE (App (mk_cons tra (tidx+1)) (Init_global_var next) [Fun (mk_cons tra (tidx+2)) x e]) (init_global_funs tra (tidx+3) (next+1) funs))`;

(* Special orphan trace for decLang. 3 is because decLang is the third lanugage. *)
val oc_tra_def = Define`
  (oc_tra = Cons orphan_trace 3)`;

val _ = Define `
  (compile_decs next [] = Con Empty NONE [])
  ∧
  (compile_decs next (d::ds) =
   case d of
   | Dlet n e =>
     let vars = (GENLIST (λn. STRCAT"x"(num_to_dec_string n)) n) in
       Let (mk_cons Empty 1) NONE (Mat (mk_cons Empty 2) e [(Pcon NONE (MAP Pvar
       vars), init_globals Empty 3 vars next)])
         (compile_decs (next+n) ds)
   | Dletrec funs =>
     let n = (LENGTH funs) in
       Let (mk_cons Empty 1) NONE (init_global_funs Empty 2 next funs) (compile_decs (next+n) ds))`;

(* TODO: Since the Lets, cons, var_local and prompts don't have a trace we'll leave them as empty *)
val _ = Define `
  (compile_prompt _ none_tag some_tag next prompt =
   case prompt of
    | Prompt ds =>
      let n = (num_defs ds) in
        (1:num, next+n,
         Let Empty NONE (Extend_global Empty n)
           (Handle Empty (Let Empty NONE (compile_decs next ds)
                     (Con Empty (SOME none_tag) []))
             [(Pvar "x",
               Con Empty (SOME some_tag) [Var_local Empty "x"])])))`;

(* c is a trace counter, which holds the value of the next trace number to be
* used. *)
val _ = Define`
  (compile_prog c none_tag some_tag next [] = (c + 1, next, Con (Cons oc_tra c) (SOME none_tag) []))
  ∧
  (compile_prog c none_tag some_tag next (p::ps) =
   let (c, next',p') = compile_prompt c none_tag some_tag next p in
   let (c, next'',ps') = compile_prog c none_tag some_tag next' ps in
     (c + 2, next'',Mat (Cons oc_tra c) p'
                        [(Pcon (SOME none_tag) [], ps'); (Pvar "x", Var_local
                        (Cons oc_tra (c + 1)) "x")]))`;

val _ = Define`
  compile conf p =
    let (c, n, e) = 
      compile_prog 1
        (none_tag, TypeId(Short"option"))
        (some_tag, TypeId(Short "option")) conf p in
          (n, e)`;

val _ = export_theory()
