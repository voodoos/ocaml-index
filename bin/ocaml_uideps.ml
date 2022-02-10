type command = Process | Aggregate | Dump
exception Unknown_command of string
exception Too_many_files
exception Too_few_files

let cmd_to_string = function
  | Process -> "process-cmt"
  | Aggregate -> "aggregate"
  | Dump -> "dump"

let cmd_of_string = function
  | "process-cmt" -> Process
  | "aggregate" -> Aggregate
  | "dump" -> Dump
  | s -> raise (Unknown_command s)

let usage_msg = "ocaml-uideps process-cmt <cmt> [<cmt>] ...
\nocaml-uideps aggregate <usage1> [<usage2>] ...
\nocaml-uideps dump <cmt>"

let command = ref Process
let input_files = ref []
let output_file : string option ref = ref None

let anon_fun  =
  let first = ref true in
  fun filename ->
    if !first then begin
      command := cmd_of_string filename;
      first := false end
    else
      input_files := filename::!input_files

let set_output_file file =
  output_file := Some file

let speclist = []

let () = try
  Arg.parse speclist anon_fun usage_msg;
  match !command, !input_files with
  | (Process | Aggregate | Dump), [] -> raise Too_few_files
  | Dump, _::_::_ -> raise Too_many_files
  | Process, files -> Uideps.generate files
  | Dump, [file] -> File_format.(read ~file |> pp_payload Format.std_formatter)
  | Aggregate, _ -> () (* todo *)
with
  Unknown_command cmd -> Printf.eprintf "Unknown command %S." cmd; exit 2
  | Too_many_files ->
      Printf.eprintf "Command %s expects exactly one input file."
        (cmd_to_string !command);
      exit 2
  | Too_few_files ->
      Printf.eprintf "Command %s requires at least one input file."
        (cmd_to_string !command);
      exit 2
