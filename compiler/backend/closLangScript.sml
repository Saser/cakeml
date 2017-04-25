open preamble backend_commonTheory;

val _ = new_theory "closLang";

val _ = set_grammar_ancestry ["ast"]

val _ = ParseExtras.tight_equality()

(* compilation from this language removes closures *)

val _ = Datatype `
  op = Global num    (* load global var with index *)
     | SetGlobal num (* assign a value to a global *)
     | AllocGlobal   (* make space for a new global *)
     | GlobalsPtr    (* get pointer to globals array *)
     | SetGlobalsPtr (* set pointer to globals array *)
     | Cons num      (* construct a Block with given tag *)
     | El            (* read Block field index *)
     | LengthBlock   (* get length of Block *)
     | Length        (* get length of reference *)
     | LengthByte    (* get length of byte array *)
     | RefByte bool  (* makes a byte array, T = immutable/compare-by-contents *)
     | RefArray      (* makes an array by replicating a value *)
     | DerefByte     (* loads a byte from a byte array *)
     | UpdateByte    (* updates a byte array *)
     | FromList num  (* convert list to packed Block *)
     | String string (* create a ByteVector from a constant *)
     | FromListByte  (* convert list of chars to ByteVector *)
     | LengthByteVec (* get length of ByteVector *)
     | DerefByteVec  (* load a byte from a ByteVector *)
     | TagLenEq num num (* check Block's tag and length *)
     | TagEq num     (* check Block's tag *)
     | Ref           (* makes a reference *)
     | Deref         (* loads a value from a reference *)
     | Update        (* updates a reference *)
     | Label num     (* constructs a CodePtr *)
     | FFI string    (* calls the FFI *)
     | Equal         (* structural equality *)
     | EqualInt int  (* equal to integer constant *)
     | Const int     (* integer *)
     | Add           (* + over the integers *)
     | Sub           (* - over the integers *)
     | Mult          (* * over the integers *)
     | Div           (* div over the integers *)
     | Mod           (* mod over the integers *)
     | Less          (* < over the integers *)
     | LessEq        (* <= over the integers *)
     | Greater       (* > over the integers *)
     | GreaterEq     (* >= over the integers *)
     | WordOp word_size opw
     | WordShift word_size shift num
     | WordFromInt
     | WordToInt
     | BoundsCheckBlock
     | BoundsCheckArray
     | BoundsCheckByte
     | LessConstSmall num`

val _ = Datatype `
  exp = Var tra num
      | If tra exp exp exp
      | Let tra (exp list) exp
      | Raise tra exp
      | Handle tra exp exp
      | Tick tra exp
      | Call tra num (* ticks *) num (* loc *) (exp list) (* args *)
      | App tra (num option) exp (exp list)
      | Fn tra (num option) (num list option) num exp
      | Letrec tra (num option) (num list option) ((num # exp) list) exp
      | Op tra op (exp list) `;

val exp_size_def = definition"exp_size_def";

val exp1_size_lemma = Q.store_thm("exp1_size_lemma",
  `!fns n x. MEM (n,x) fns ==> exp_size x < exp1_size fns`,
  Induct \\ fs [FORALL_PROD,exp_size_def] \\ REPEAT STRIP_TAC
  \\ RES_TAC \\ SRW_TAC [] [] \\ DECIDE_TAC);

val pure_op_def = Define `
  pure_op op ⇔
    case op of
      FFI _ => F
    | SetGlobal _ => F
    | AllocGlobal => F
    | (RefByte _) => F
    | RefArray => F
    | UpdateByte => F
    | Ref => F
    | Update => F
    | _ => T
`;

(* pure e means e can neither raise an exception nor side-effect the state *)
val pure_def = tDefine "pure" `
  (pure (Var _ _) ⇔ T)
    ∧
  (pure (If _ e1 e2 e3) ⇔ pure e1 ∧ pure e2 ∧ pure e3)
    ∧
  (pure (Let _ es e2) ⇔ EVERY pure es ∧ pure e2)
    ∧
  (pure (Raise _ _) ⇔ F)
    ∧
  (pure (Handle _ e1 _) ⇔ pure e1)
    ∧
  (pure (Tick _ _) ⇔ F)
    ∧
  (pure (Call _ _ _ _) ⇔ F)
    ∧
  (pure (App _ _ _ _) ⇔ F)
    ∧
  (pure (Fn _ _ _ _ _) ⇔ T)
    ∧
  (pure (Letrec _ _ _ _ x) ⇔ pure x)
    ∧
  (pure (Op _ opn es) ⇔ EVERY pure es ∧ pure_op opn)
` (WF_REL_TAC `measure exp_size` >> simp[] >> rpt conj_tac >> rpt gen_tac >>
   (Induct_on `es` ORELSE Induct_on `fns`) >> dsimp[exp_size_def] >>
   rpt strip_tac >> res_tac >> simp[])

val _ = export_theory()
