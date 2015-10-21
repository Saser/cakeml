open preamble bvlSemTheory bvpSemTheory bvpPropsTheory copying_gcTheory
     int_bitwiseTheory bvp_to_wordPropsTheory finite_mapTheory
     bvp_to_wordTheory;

val _ = new_theory "bvp_to_wordProof";

(* -------------------------------------------------------
    TODO:
     - sketch compiler proof
       - prove Call
       - prove MakeSpace
       - prove Assign Const
   ------------------------------------------------------- *)

(* definition of state relation *)

val isWord_def = Define `
  (isWord (Word w) = T) /\ (isWord _ = F)`;

val theWord_def = Define `
  theWord (Word w) = w`;

val code_rel_def = Define `
  code_rel c s_code t_code <=>
    !n arg_count prog.
      (lookup n s_code = SOME (arg_count:num,prog)) ==>
      (lookup n t_code = SOME (arg_count,FST (comp c n 1 prog),arg_count))`

val stack_rel_def = Define `
  (stack_rel (Env env) (StackFrame vs NONE) <=>
     !n. IS_SOME (lookup n env) <=>
         IS_SOME (lookup (adjust_var n) (fromAList vs))) /\
  (stack_rel (Exc env n) (StackFrame vs (SOME (x1,x2,x3))) <=>
     stack_rel (Env env) (StackFrame vs NONE) /\ (x1 = n)) /\
  (stack_rel _ _ <=> F)`

val mapi_def = Define `
  mapi f = foldi (\n x t. insert n (f n x) t) 0 LN`

val join_env_def = Define `
  join_env env vs =
    mapi (\n v. (v,THE (ALOOKUP vs (adjust_var n)))) env`

val flat_def = Define `
  (flat (Env env::xs) (StackFrame vs _::ys) =
     join_env env vs :: flat xs ys) /\
  (flat (Exc env _::xs) (StackFrame vs _::ys) =
     join_env env vs :: flat xs ys) /\
  (flat _ _ = [])`

val the_global_def = Define `
  the_global g = the (Number 0) (OPTION_MAP RefPtr g)`;

val state_rel_def = Define `
  state_rel c l1 l2 (s:'ffi bvpSem$state) (t:('a,'ffi) wordSem$state) v1 <=>
    (* I/O, clock and handler are the same, GC is fixed, code is compiled *)
    (t.ffi = s.ffi) /\
    (t.clock = s.clock) /\
    (t.handler = s.handler) /\
    (t.gc_fun = word_gc_fun c) /\
    code_rel c s.code t.code /\
    (* the store contains everything except Handler *)
    EVERY (\n. n IN FDOM t.store /\ isWord (t.store ' n))
      [NextFree; LastFree; FreeCount; CurrHeap; OtherHeap; AllocSize; ProgStart] /\
    EVERY (\n. n IN FDOM t.store) [Globals] /\
    (* every local is represented in word lang *)
    (v1 = LN ==> lookup 0 t.locals = SOME (Loc l1 l2)) /\
    (!n. IS_SOME (lookup n s.locals) ==>
         IS_SOME (lookup (adjust_var n) t.locals)) /\
    (* the stacks contain the same names, have same shape *)
    EVERY2 stack_rel s.stack t.stack /\
    (* there exists some GC-compatible abstraction *)
    ?heap limit a sp.
      (* the abstract heap is stored in memory *)
      (word_heap (theWord (t.store ' CurrHeap)) heap c heap *
       word_heap (theWord (t.store ' OtherHeap))
         [Unused (limit-1)] c [Unused (limit-1)])
           (fun2set (t.memory,t.mdomain)) /\
      (* the abstract heap relates to the values of BVP *)
      word_ml_envs (heap,F,a,sp) limit c s.refs
        (v1 :: join_env s.locals (toAList t.locals) ::
           LS (the_global s.global,t.store ' Globals) ::
           flat s.stack t.stack) /\
      s.space <= sp`

(* compiler proof *)

val state_rel_get_var_IMP = prove(
  ``state_rel c l1 l2 s t LN ==>
    (get_var n s = SOME x) ==>
    ?w. get_var (adjust_var n) t = SOME w``,
  fs [bvpSemTheory.get_var_def,wordSemTheory.get_var_def]
  \\ fs [state_rel_def] \\ rpt strip_tac
  \\ `IS_SOME (lookup n s.locals)` by fs [] \\ res_tac
  \\ Cases_on `lookup (adjust_var n) t.locals` \\ fs []);

val state_rel_get_vars_IMP = prove(
  ``!n xs.
      state_rel c l1 l2 s t LN ==>
      (get_vars n s = SOME xs) ==>
      ?ws. get_vars (MAP adjust_var n) t = SOME ws /\ (LENGTH xs = LENGTH ws)``,
  Induct \\ fs [bvpSemTheory.get_vars_def,wordSemTheory.get_vars_def]
  \\ rpt strip_tac
  \\ Cases_on `get_var h s` \\ fs []
  \\ Cases_on `get_vars n s` \\ fs [] \\ rw []
  \\ imp_res_tac state_rel_get_var_IMP \\ fs []);

val state_rel_0_get_vars_IMP = prove(
  ``state_rel c l1 l2 s t LN ==>
    (get_vars n s = SOME xs) ==>
    ?ws. get_vars (0::MAP adjust_var n) t = SOME ((Loc l1 l2)::ws) /\
         (LENGTH xs = LENGTH ws)``,
  rpt strip_tac
  \\ imp_res_tac state_rel_get_vars_IMP
  \\ fs [wordSemTheory.get_vars_def]
  \\ fs [state_rel_def,wordSemTheory.get_var_def]);

val get_var_T_OR_F = prove(
  ``state_rel c l1 l2 s (t:('a,'ffi) state) LN /\
    get_var n s = SOME x /\
    get_var (adjust_var n) t = SOME w ==>
    6 MOD dimword (:'a) <> 2 MOD dimword (:'a) /\
    ((x = Boolv T) ==> (w = Word 2w)) /\
    ((x = Boolv F) ==> (w = Word 6w))``,
  cheat);

val state_rel_jump_exc = prove(
  ``state_rel c l1 l2 s t LN /\
    get_var n s = SOME x /\
    get_var (adjust_var n) t = SOME w /\
    jump_exc s = SOME s1 ==>
    ?t1 d1 d2. jump_exc t = SOME (t1,d1,d2) /\
               state_rel c l1 l2 s1 t1 (LS (x,w))``,
  cheat);

val mk_loc_def = Define `
  mk_loc (SOME (t1,d1,d2)) = Loc d1 d2`;

val evaluate_mk_loc_EQ = prove(
  ``evaluate (q,t) = (NONE,t1:('a,'ffi) state) ==>
    mk_loc (jump_exc t1) = ((mk_loc (jump_exc t)):'a word_loc)``,
  cheat);

val find_code_lemma = prove(
  ``find_code dest x s.code = SOME (q,r) /\
    state_rel c l1 l2 s t LN /\ (LENGTH x = LENGTH ws) ==>
    ?n args. find_code dest ws t.code = SOME (args,FST (comp c n 1 r))``,
  reverse (Cases_on `dest`) \\ fs [find_code_def]
  \\ BasicProvers.EVERY_CASE_TAC \\ fs [] \\ rw []
  \\ fs [state_rel_def,code_rel_def] \\ res_tac
  \\ fs [wordSemTheory.find_code_def] THEN1 metis_tac []
  \\ cheat)

val cut_env_IMP_cut_env = prove(
  ``state_rel c l1 l2 s t LN /\
    bvpSem$cut_env r s.locals = SOME x ==>
    ?y. wordSem$cut_env (adjust_set r) t.locals = SOME y``,
  fs [bvpSemTheory.cut_env_def,wordSemTheory.cut_env_def]
  \\ fs [adjust_set_def,domain_fromAList,SUBSET_DEF,MEM_MAP,
         PULL_EXISTS,sptreeTheory.domain_lookup,lookup_fromAList] \\ rw []
  \\ Cases_on `x' = 0` \\ fs [] THEN1 fs [state_rel_def]
  \\ imp_res_tac alistTheory.ALOOKUP_MEM
  \\ fs [MEM_MAP] \\ rw[] \\ fs [] \\ Cases_on `y` \\ fs [] \\ rw []
  \\ fs [MEM_toAList] \\ res_tac
  \\ fs [state_rel_def] \\ res_tac
  \\ `IS_SOME (lookup q s.locals)` by fs [] \\ res_tac
  \\ Cases_on `lookup (adjust_var q) t.locals` \\ fs []);

val jump_exc_call_env = prove(
  ``wordSem$jump_exc (call_env x s) = jump_exc s``,
  fs [wordSemTheory.jump_exc_def,wordSemTheory.call_env_def]);

val jump_exc_dec_clock = prove(
  ``mk_loc (wordSem$jump_exc (dec_clock s)) = mk_loc (jump_exc s)``,
  fs [wordSemTheory.jump_exc_def,wordSemTheory.dec_clock_def]
  \\ rw [] \\ BasicProvers.EVERY_CASE_TAC \\ fs [mk_loc_def]);

val jump_exc_push_env_NONE = prove(
  ``jump_exc (push_env y NONE s) = jump_exc s``,
  cheat);

val state_rel_ARB_ret = prove(
  ``state_rel c l1 l2 s t (LS x) = state_rel c ARB ARB s t (LS x)``,
  fs [state_rel_def]);

val compile_correct = prove(
  ``!(prog:bvp$prog) (s:'ffi bvpSem$state) c n l l1 l2 res s1 (t:('a,'ffi)wordSem$state).
      (bvpSem$evaluate (prog,s) = (res,s1)) /\
      res <> SOME (Rerr (Rabort Rtype_error)) /\
      state_rel c l1 l2 s t LN ==>
      ?t1 res1. (wordSem$evaluate (FST (comp c n l prog),t) = (res1,t1)) /\
                (res1 <> SOME NotEnoughSpace ==>
                 case res of
                 | NONE => state_rel c l1 l2 s1 t1 LN /\ (res1 = NONE)
                 | SOME (Rval v) =>
                     ?w. state_rel c l1 l2 s1 t1 (LS (v,w)) /\
                         (res1 = SOME (Result (Loc l1 l2) w))
                 | SOME (Rerr (Rraise v)) =>
                     ?w. state_rel c l1 l2 s1 t1 (LS (v,w)) /\
                         (res1 = SOME (Exception (mk_loc (jump_exc t)) w))
                 | SOME (Rerr (Rabort e)) => (res1 = SOME TimeOut))``,
  recInduct bvpSemTheory.evaluate_ind \\ rpt strip_tac \\ fs []
  THEN1 (* Skip *)
   (fs [comp_def,bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ rw [])
  THEN1 (* Move *)
   (fs [comp_def,bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ Cases_on `get_var src s` \\ fs [] \\ rw []
    \\ fs [] \\ imp_res_tac state_rel_get_var_IMP \\ fs []
    \\ fs [wordSemTheory.get_vars_def,wordSemTheory.set_vars_def,
           alist_insert_def]
    \\ fs [state_rel_def,set_var_def,lookup_insert]
    \\ rpt strip_tac \\ fs []
    THEN1 (rw [] \\ Cases_on `n = dest` \\ fs [])
    \\ Q.LIST_EXISTS_TAC [`heap`,`limit`,`a`,`sp`] \\ fs []
    \\ imp_res_tac word_ml_envs_get_var_IMP
    \\ match_mp_tac word_ml_envs_insert \\ fs [])
  THEN1 (* Assign *) cheat
  THEN1 (* Tick *)
   (fs [comp_def,bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ `t.clock = s.clock` by fs [state_rel_def] \\ fs [] \\ rw []
    \\ fs [] \\ rw [] \\ rpt (pop_assum mp_tac)
    \\ fs [wordSemTheory.jump_exc_def,wordSemTheory.dec_clock_def] \\ rw []
    \\ fs [state_rel_def,bvpSemTheory.dec_clock_def,wordSemTheory.dec_clock_def]
    \\ Q.LIST_EXISTS_TAC [`heap`,`limit`,`a`,`sp`] \\ fs [])
  THEN1 (* MakeSpace *)
   (fs [comp_def,bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ rpt (pop_assum mp_tac) \\ BasicProvers.CASE_TAC \\ rpt strip_tac
    \\ rw []
    \\ fs [add_space_def]
    \\ cheat)
  THEN1 (* Raise *)
   (fs [comp_def,bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ Cases_on `get_var n s` \\ fs [] \\ rw []
    \\ fs [] \\ imp_res_tac state_rel_get_var_IMP \\ fs []
    \\ Cases_on `jump_exc s` \\ fs [] \\ rw []
    \\ imp_res_tac state_rel_jump_exc \\ fs []
    \\ rw [] \\ fs [] \\ rw [mk_loc_def])
  THEN1 (* Return *)
   (fs [comp_def,bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ Cases_on `get_var n s` \\ fs [] \\ rw []
    \\ `get_var 0 t = SOME (Loc l1 l2)` by
          fs [state_rel_def,wordSemTheory.get_var_def]
    \\ fs [] \\ imp_res_tac state_rel_get_var_IMP \\ fs []
    \\ fs [state_rel_def,wordSemTheory.call_env_def,lookup_def,
           bvpSemTheory.call_env_def,EVAL ``fromList []``,
           EVAL ``isEmpty (insert 0 x LN)``,EVAL ``fromList2 []``,
           EVAL ``join_env LN (toAList LN)``]
    \\ Q.LIST_EXISTS_TAC [`heap`,`limit`,`a`,`sp`] \\ fs []
    \\ imp_res_tac word_ml_envs_get_var_IMP
    \\ imp_res_tac word_ml_envs_DROP)
  THEN1 (* Seq *)
   (once_rewrite_tac [bvp_to_wordTheory.comp_def] \\ fs []
    \\ Cases_on `comp c n l c1` \\ fs [LET_DEF]
    \\ Cases_on `comp c n r c2` \\ fs [LET_DEF]
    \\ fs [bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ Cases_on `evaluate (c1,s)` \\ fs [LET_DEF]
    \\ `q'' <> SOME (Rerr (Rabort Rtype_error))` by
         (Cases_on `q'' = NONE` \\ fs []) \\ fs []
    \\ qpat_assum `state_rel c l1 l2 s t LN` (fn th =>
           first_x_assum (fn th1 => mp_tac (MATCH_MP th1 th)))
    \\ strip_tac \\ pop_assum (mp_tac o Q.SPECL [`n`,`l`])
    \\ rpt strip_tac \\ rfs[]
    \\ reverse (Cases_on `q'' = NONE`) \\ fs []
    THEN1 (rpt strip_tac \\ fs [] \\ rw [] \\ Cases_on `q''` \\ fs []
           \\ Cases_on `x` \\ fs [] \\ Cases_on `e` \\ fs [])
    \\ rw [] THEN1
     (qpat_assum `state_rel c l1 l2 s t LN` (fn th =>
             first_x_assum (fn th1 => mp_tac (MATCH_MP th1 th)))
      \\ strip_tac \\ pop_assum (mp_tac o Q.SPECL [`n`,`r`])
      \\ rpt strip_tac \\ rfs [] \\ rpt strip_tac \\ fs []
      \\ BasicProvers.EVERY_CASE_TAC \\ fs [mk_loc_def] \\ fs []
      \\ imp_res_tac evaluate_mk_loc_EQ \\ fs [])
    \\ Cases_on `res` \\ fs [])
  THEN1 (* If *)
   (once_rewrite_tac [bvp_to_wordTheory.comp_def] \\ fs []
    \\ Cases_on `comp c n l c1` \\ fs [LET_DEF]
    \\ Cases_on `comp c n r c2` \\ fs [LET_DEF]
    \\ fs [bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    \\ Cases_on `get_var n s` \\ fs []
    \\ fs [] \\ imp_res_tac state_rel_get_var_IMP
    \\ fs [wordSemTheory.get_var_imm_def,asmSemTheory.word_cmp_def]
    \\ imp_res_tac get_var_T_OR_F
    \\ Cases_on `x = Boolv T` \\ fs [] THEN1
     (qpat_assum `state_rel c l1 l2 s t LN` (fn th =>
               first_x_assum (fn th1 => mp_tac (MATCH_MP th1 th)))
      \\ strip_tac \\ pop_assum (qspecl_then [`n`,`l`] mp_tac)
      \\ rpt strip_tac \\ rfs[])
    \\ Cases_on `x = Boolv F` \\ fs [] THEN1
     (qpat_assum `state_rel c l1 l2 s t LN` (fn th =>
               first_x_assum (fn th1 => mp_tac (MATCH_MP th1 th)))
      \\ strip_tac \\ pop_assum (qspecl_then [`n`,`r`] mp_tac)
      \\ rpt strip_tac \\ rfs[]))
  THEN1 (* Call *)
   (once_rewrite_tac [bvp_to_wordTheory.comp_def] \\ fs []
    \\ Cases_on `ret`
    \\ fs [bvpSemTheory.evaluate_def,wordSemTheory.evaluate_def]
    THEN1 (* ret = NONE *)
     (Cases_on `get_vars args s` \\ fs []
      \\ imp_res_tac state_rel_0_get_vars_IMP \\ fs []
      \\ Cases_on `find_code dest x s.code` \\ fs []
      \\ Cases_on `x'` \\ fs [] \\ Cases_on `handler` \\ fs []
      \\ imp_res_tac find_code_lemma \\ fs []
      \\ `t.clock = s.clock` by fs [state_rel_def]
      \\ Cases_on `s.clock = 0` \\ fs [] \\ rw []
      \\ `find_code dest (Loc l1 l2::ws) t.code =
          SOME (args',FST (comp c n''' 1 r))` by cheat (* wordSem tail-call
            case needs updating to not include return value in arg length check *)
      \\ fs []
      \\ Cases_on `evaluate (r,call_env q (dec_clock s))` \\ fs []
      \\ Cases_on `q'` \\ fs [] \\ rw [] \\ fs []
      \\ `state_rel c l1 l2 (call_env q (dec_clock s))
            (call_env args' (dec_clock t)) LN` by cheat
      \\ qpat_assum `state_rel c l1 l2 s1 t1 LN` (fn th =>
               first_x_assum (fn th1 => mp_tac (MATCH_MP th1 th)))
      \\ Q.MATCH_ASSUM_RENAME_TAC `find_code dest (Loc l1 l2::ws) t.code =
           SOME (args',FST (comp c n6 1 r))`
      \\ strip_tac \\ pop_assum (qspecl_then [`n6`,`1`] mp_tac)
      \\ rpt strip_tac \\ fs []
      \\ Cases_on `res1` \\ fs [] \\ rw [] \\ fs []
      \\ BasicProvers.EVERY_CASE_TAC \\ fs [mk_loc_def]
      \\ fs [wordSemTheory.jump_exc_def,wordSemTheory.call_env_def,
             wordSemTheory.dec_clock_def]
      \\ BasicProvers.EVERY_CASE_TAC \\ fs [mk_loc_def])
    \\ Cases_on `x` \\ fs [LET_DEF]
    \\ Cases_on `handler` \\ fs [wordSemTheory.evaluate_def]
    \\ Cases_on `get_vars args s` \\ fs []
    \\ imp_res_tac state_rel_get_vars_IMP \\ fs []
    THEN1 (* no handler *)
     (Cases_on `find_code dest x s.code` \\ fs []
      \\ Cases_on `x'` \\ imp_res_tac find_code_lemma \\ fs [] \\ rw []
      \\ qpat_assum `xx = (res,s1)` mp_tac \\ NTAC 2 BasicProvers.CASE_TAC
      \\ rw [] \\ fs [] \\ `t.clock = s.clock` by fs [state_rel_def] \\ fs []
      \\ imp_res_tac cut_env_IMP_cut_env \\ fs [] \\ rw []
      \\ Cases_on `evaluate (r',call_env q' (push_env x' F (dec_clock s)))` \\ fs []
      \\ Cases_on `q'' = SOME (Rerr (Rabort Rtype_error))` \\ fs []
      \\ `state_rel c q l
           (call_env q' (push_env x' F (dec_clock s)))
           (call_env (Loc q l::args') (push_env y
    (NONE :(num # ('a wordLang$prog) # num # num) option) (dec_clock t))) LN`
               by cheat
      \\ qpat_assum `state_rel c' l1' l2' s1' t1' LN'` (fn th =>
               first_x_assum (fn th1 => mp_tac (MATCH_MP th1 th)))
      \\ strip_tac \\ pop_assum (qspecl_then [`n`,`1`] mp_tac)
      \\ rpt strip_tac \\ fs []
      \\ Cases_on `res1 = SOME NotEnoughSpace` \\ fs []
      \\ Cases_on `q''` \\ fs [] \\ Cases_on `x''` \\ fs []
      THEN1 (* normal return *)
       (Cases_on `pop_env r''` \\ fs [] \\ rw []
        \\ rpt strip_tac \\ fs [] \\ cheat)
      \\ Cases_on `e` \\ fs [] \\ rw []
      \\ fs [jump_exc_call_env,jump_exc_dec_clock,jump_exc_push_env_NONE]
      \\ pop_assum mp_tac \\ once_rewrite_tac [state_rel_ARB_ret] \\ fs [])
    \\ cheat));

val _ = export_theory();