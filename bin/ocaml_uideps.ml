open Lib

type command = Process | Aggregate | Dump | Usage

exception Unknown_command of string
exception Too_many_files
exception Too_few_files

let cmd_to_string = function
  | Process -> "process-cmt"
  | Aggregate -> "aggregate"
  | Dump -> "dump"
  | Usage -> "usage"

let cmd_of_string = function
  | "process-cmt" -> Process
  | "aggregate" -> Aggregate
  | "dump" -> Dump
  | s -> raise (Unknown_command s)

let usage_msg =
  "ocaml-uideps process-cmt <cmt> [<build-path>] ...\n\n\
   ocaml-uideps aggregate -o <output> <uideps> [<uideps>] ...\n\n\
   ocaml-uideps dump <cmt>"

let command = ref Usage
let verbose = ref false
let debug = ref false
let input_files = ref []
let output_file = ref "workspace.uideps"
let root = ref "."

let anon_fun =
  let first = ref true in
  fun filename ->
    if !first then (
      command := cmd_of_string filename;
      first := false)
    else input_files := filename :: !input_files

let speclist =
  [
    ("--verbose", Arg.Set verbose, "Output log information");
    ("--debug", Arg.Set debug, "Output debug information");
    ("-o", Arg.Set_string output_file, "Set output file name");
    ("--debug", Arg.Set debug, "Output debug information");
    ("--root", Arg.Set_string root, "Root path");
  ]

let () =
  try
    Arg.parse speclist anon_fun usage_msg;
    if !verbose then Log.set_log_level Warning;
    if !debug then Log.set_log_level Debug;
    match (!command, List.rev !input_files) with
    | (Dump | Process), [] -> raise Too_few_files
    | Dump, _ :: _ :: _ -> raise Too_many_files
    | Process, file :: build_path ->
        let root = if !root = "." then None else Some !root in
        Uideps.generate ~root ~output_file:!output_file ~build_path file
    | Dump, [ file ] ->
        File_format.(read ~file |> pp_payload Format.std_formatter)
    | Aggregate, files -> Uideps.aggregate ~output_file:!output_file files
    | Usage, _ -> Format.print_string usage_msg
  with
  | Unknown_command cmd ->
      Printf.eprintf "Unknown command %S." cmd;
      exit 2
  | Too_many_files ->
      Printf.eprintf "Command %s expects exactly one input file."
        (cmd_to_string !command);
      exit 2
  | Too_few_files ->
      Printf.eprintf "Command %s requires at least one input file."
        (cmd_to_string !command);
      exit 2
