open preamble
     lexer_funTheory
     cmlParseTheory
     inferTheory
     backendTheory
     basisProgTheory
open jsonTheory

(* COMPILING *)
val _ = Define`
  basic_prog = "val (x,y) = (3 + 5, 1); val y = \"hello\"; val x = (3)"`;
val _ = Define`
  parse p = parse_prog (MAP FST (lexer_fun p))`;

val _ = Define`
  parsed_basic =
    case parse basic_prog of
         NONE => [] 
       | SOME x => x`;

EVAL ``parse_basic``;
EVAL ``source_to_mod$ast_to_pres parsed_basic``;

(* JSON *)
val _ = Define `
  json =
    (Object [
              ("modLang", Array [
                          Null;
                          Bool T;
                          Bool F;
                          String "Hello, World!";
                          Object [("n", Null); ("b", Bool T)];
                          Int (-9999999999999999999999999999999999999999999999999999999122212)
                        ]
              )
            ]
    )`;

EVAL ``json_to_string json``;
