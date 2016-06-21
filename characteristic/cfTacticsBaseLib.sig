signature cfTacticsBaseLib =
sig
  include Abbrev

  type conseq_conv = ConseqConv.conseq_conv
  type directed_conseq_conv = ConseqConv.directed_conseq_conv

  val find_map : ('a -> 'b option) -> 'a list -> 'b option

  val NCONV : int -> conv -> conv
  val UNCHANGED_CONV : conv -> conv

  val CUSTOM_THEN_CONSEQ_CONV :
    (exn -> bool) -> (exn -> bool) ->
    conseq_conv -> conseq_conv -> conseq_conv

  val handle_none : exn -> bool
  val handle_UNCHANGED : exn -> bool

  (* This has different semantics than [ConseqConv.THEN_CONSEQ_CONV], but I
     believe these are the right ones.

     Just like [Conv.THENC], it fails if either the first or the second
     conversion fails, while [ConseqConv.THEN_CONSEQ_CONV] handles a failure
     just like raising [UNCHANGED], which makes it impossible to make the first
     conversion abort a THEN_CONSEQ_CONV.
  *)
  val THEN_CONSEQ_CONV : conseq_conv -> conseq_conv -> conseq_conv

  (* Similarly, this one has different semantics than
     [ConseqConv.ORELSE_CONSEQ_CONV], and instead matches the semantics of
     [Conv.ORELSEC]
  *)
  val ORELSE_CONSEQ_CONV : conseq_conv -> conseq_conv -> conseq_conv

  val CUSTOM_THEN_DCC :
    (conseq_conv -> conseq_conv -> conseq_conv) ->
    directed_conseq_conv -> directed_conseq_conv -> directed_conseq_conv

  (* Has the same semantics as THEN_CONSEQ_CONV *)
  val THEN_DCC :
    directed_conseq_conv * directed_conseq_conv -> directed_conseq_conv

  (* Has the same semantics as ORELSE_CONSEQ_CONV *)
  val ORELSE_DCC :
    directed_conseq_conv * directed_conseq_conv -> directed_conseq_conv

  val EVERY_DCC : directed_conseq_conv list -> directed_conseq_conv
  val CHANGED_DCC : directed_conseq_conv -> directed_conseq_conv
  val QCHANGED_DCC : directed_conseq_conv -> directed_conseq_conv

  val TOP_REDEPTH_CONSEQ_CONV : directed_conseq_conv -> directed_conseq_conv

  val CONJ_CONSEQ_CONV : conseq_conv -> conseq_conv -> conseq_conv
  val CONJ1_CONSEQ_CONV : conseq_conv -> conseq_conv
  val CONJ2_CONSEQ_CONV : conseq_conv -> conseq_conv
  val CONJ_LIST_CONSEQ_CONV : conseq_conv list -> conseq_conv

  val DISJ_CONSEQ_CONV : conseq_conv -> conseq_conv -> conseq_conv
  val DISJ1_CONSEQ_CONV : conseq_conv -> conseq_conv
  val DISJ2_CONSEQ_CONV : conseq_conv -> conseq_conv
  val DISJ_LIST_CONSEQ_CONV : conseq_conv list -> conseq_conv

  val IMP_CONSEQ_CONV : conseq_conv -> conseq_conv -> conseq_conv
  val IMP_ASSUM_CONSEQ_CONV : conseq_conv -> conseq_conv
  val IMP_CONCL_CONSEQ_CONV : conseq_conv -> conseq_conv
  val IMP_LIST_CONSEQ_CONV : conseq_conv list -> conseq_conv

  val STRIP_FORALL_CONSEQ_CONV : conseq_conv -> conseq_conv
  val STRIP_EXISTS_CONSEQ_CONV : conseq_conv -> conseq_conv

  val print_cc : conseq_conv
  val print_dcc : directed_conseq_conv

  val MATCH_IMP_STRENGTHEN_CONSEQ_CONV : thm -> conseq_conv
  
  (** Tactics to deal with goals of the form [?x1..xn. A1 /\ ... /\ Am], where
      the [Ai]s are not themselves of the form [_ /\ _], and shouldn't start
      with existential quantifications. The focus is on A1 (the "head"), where
      most of the work is usually done.
   *)

  type econj = {evars: term list, head_conj: term, rest: term list}

  val dest_econj : term -> econj
  val mk_econj : econj -> term
  val is_econj : term -> bool
  val normalize_to_econj_conv : conv

  val econj_head_conseq_conv : conseq_conv -> conseq_conv

  val econj_nth_irule_conseq_conv : int -> thm -> conseq_conv
  val econj_head_irule_conseq_conv : thm -> conseq_conv

  (* Tactics *)

  val normalize_to_econj : tactic
  val econj_nth_irule : int -> thm -> tactic
  val econj_head_irule : thm -> tactic
end
