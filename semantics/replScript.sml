open preamble;
open ASCIInumbersTheory;
open BigStepTheory TypeSystemTheory AstTheory ElabTheory lexer_funTheory;
open InitialEnvTheory;
open gramTheory cmlPtreeConversionTheory;

val _ = new_theory "repl";

val _ = Hol_datatype `
repl_state = <| (* Elaborator state *)
                type_bindings : tdef_env; ctors : ctor_env;
                (* Type system state *)
                tenvM : tenvM; tenvC : tenvC; tenv : tenvE;
                (* Semantics state *)
                envM : envM; envC : envC; store : store; envE : envE |>`;

val init_repl_state_def = Define`
  init_repl_state = <| type_bindings := init_type_bindings; ctors := [];
                       tenvM := []; tenvC := init_tenvC; tenv := init_tenv;
                       envM := []; envC := init_envC; store := []; envE := init_env |>`

val _ = Hol_datatype `
repl_result =
    Terminate
  | Diverge
  | Result of string => repl_result`;

val strip_mod_env_def = Define `
strip_mod_env tenvM =
  MAP (\(n,tenv). (n,[])) tenvM`;

val update_repl_state_def = Define `
update_repl_state ast state type_bindings ctors tenvM tenvC tenv store envC r =
  case r of
    | Rval (envM,envE) =>
        <| type_bindings := type_bindings ++ state.type_bindings;
           ctors := ctors ++ state.ctors;
           tenvM := tenvM ++ state.tenvM;
           tenvC := tenvC ++ state.tenvC;
           tenv := bind_var_list2 tenv state.tenv;
           store := store;
           envM := envM ++ state.envM;
           envC := envC ++ state.envC;
           envE := envE ++ state.envE |>
    | Rerr _ =>
        (* We need to record the attempted module names (if any), so that it
        * can't be defined later.  To avoid the situation where a failing module
        * defines some datatype constructors and puts them into the store before
        * failing.  Then a later same-name module could redefine the constructos
        * with different types.  But its bindings aren't available, so strip
        * them out.  For similar reasons we must remember the constructors that
        * have been defined in the operational semantics (but not the type
        * system).  Here we use all of the constructors from the module, but we
        * could also just use the ones whose definitions were reached.  Since
        * they don't go in the constructor type environment, the programmer
        * can't refer to any of them, so it doesn't matter much. *)
        state with <| store := store;
                      envC := top_to_cenv ast ++ state.envC;
                      envM := strip_mod_env tenvM ++ state.envM;
                      tenvM := strip_mod_env tenvM ++ state.tenvM |>`;

val print_envM_def = Define `
print_envM envM = CONCAT (MAP (λ(x,m). "module " ++ x ++ " = <structure>\n") envM)`;

val print_envC_def = Define `
print_envC envC = CONCAT (MAP (λ(x,c). id_to_string x ++ " = <constructor>\n") envC)`;

val print_lit_def = Define `
(print_lit (IntLit i) = int_to_string i) ∧
(print_lit (Bool T) = "true") ∧
(print_lit (Bool F) = "false") ∧
(print_lit Unit = "()")`;

val print_v_def = Define `
(print_v (Litv l) = print_lit l) ∧
(print_v (Conv _ _) = "<constructor>") ∧
(print_v (Closure _ _ _) = "<fn>") ∧
(print_v (Recclosure _ _ _) = "<fn>") ∧
(print_v (Loc _) = "<ref>")`;

val print_tc_def = Define`
  (print_tc (TC_name tid) = id_to_string tid) ∧
  (print_tc TC_int = "int") ∧
  (print_tc TC_bool = "bool") ∧
  (print_tc TC_unit = "unit") ∧
  (print_tc TC_ref = "ref") ∧
  (print_tc TC_fn = "fn") ∧
  (print_tc TC_tup = "tup") ∧
  (print_tc TC_exn = "exn")`

val print_t_def = Define`
  (print_t (Tvar a) = "'"++a) ∧
  (print_t (Tvar_db n) = "'"++num_to_dec_string n) ∧
  (print_t (Tapp _ tc) = print_tc tc)`

val print_type_def = Define`
  (print_type (SOME (_,t)) = print_t t) ∧
  (print_type NONE = "<bad>")`

val print_envE_def = Define `
print_envE tenv envE = CONCAT (MAP (\(x,v). "val " ++ x ++ " : " ++ print_type (lookup x tenv) ++ " = " ++ print_v v ++ "\n") envE)`;

val print_result_def = Define `
(print_result (Tdec _) tenv envC (Rval (envM,envE)) = print_envC envC ++ print_envE tenv envE) ∧
(print_result (Tmod mn _ _) _ _ (Rval _) = "structure "++mn++" = <structure>\n") ∧
(print_result _ _ _ (Rerr Rtimeout_error) = "<timeout error>\n") ∧
(print_result _ _ _ (Rerr Rtype_error) = "<type error>\n") ∧
(print_result _ _ _ (Rerr (Rraise e)) = "raise " ++ print_v e ++ "\n")`;

val (ast_repl_rules, ast_repl_ind, ast_repl_cases) = Hol_reln `

(!state.
  ast_repl state [] [] Terminate) ∧

(!state type_errors ast asts top rest type_bindings' ctors' tenvM' tenvC' tenv' store' envC' r.
  (elab_top state.type_bindings state.ctors ast =
   (type_bindings', ctors', top)) ∧
  (type_top state.tenvM state.tenvC state.tenv top tenvM' tenvC' tenv') ∧
  evaluate_top state.envM state.envC state.store state.envE top (store',envC',r) ∧
  ast_repl (update_repl_state top state type_bindings' ctors' tenvM' tenvC' tenv' store' envC' r) type_errors asts rest
  ⇒
  ast_repl state (F::type_errors) (SOME ast::asts) (Result (print_result top tenv' envC' r) rest)) ∧

(!state type_errors ast asts top type_bindings' ctors' tenvM' tenvC' tenv'.
  (elab_top state.type_bindings state.ctors ast =
   (type_bindings', ctors', top)) ∧
  (type_top state.tenvM state.tenvC state.tenv top tenvM' tenvC' tenv') ∧
  top_diverges state.envM state.envC state.store state.envE top
  ⇒
  ast_repl state (F::type_errors) (SOME ast::asts) Diverge) ∧

(!state type_errors ast asts rest.
  ast_repl state type_errors asts rest
  ⇒
  ast_repl state (T::type_errors) (SOME ast::asts) (Result "<type error>\n" rest)) ∧

(!state x type_errors asts rest.
  ast_repl state type_errors asts rest
  ⇒
  ast_repl state (x::type_errors) (NONE::asts) (Result "<parse error>\n" rest))`;

val parse_def = Define`
  parse toks =
    case some pt. valid_ptree cmlG pt ∧ ptree_head pt = NT (mkNT nREPLTop) ∧
                  ptree_fringe pt = MAP TOK toks
    of
       NONE => NONE
     | SOME p => ptree_REPLTop p
`

val repl_def = Define `
repl type_errors input = ast_repl init_repl_state type_errors (MAP parse (split_top_level_semi (lexer_fun input)))`;

val _ = export_theory ();
