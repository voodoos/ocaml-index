(** The indexer's binary *)

open Lib

let usage_msg = "ocaml-index [COMMAND] [-verbose] <file1> [<file2>] ... -o <output>"
let verbose = ref false
let debug = ref false
let input_files = ref []
let build_path = ref []
let output_file = ref "project.ocaml-index"
let root = ref ""
let store_shapes = ref false

type command = Aggregate | Dump
let parse_command = function
  | "aggregate" -> Some Aggregate
  | "dump" -> Some Dump
  | _ -> None
let command = ref None
let anon_fun arg =
    match !command with
    | None ->
      begin match parse_command arg with
      | Some cmd -> command := Some cmd
      | None -> command := Some Aggregate; input_files := arg::!input_files
    end
    | Some _ -> input_files := arg::!input_files

let speclist =
  [("--verbose", Arg.Set verbose, "Output more information");
   ("--debug", Arg.Set debug, "Output debugging information");
   ("-o", Arg.Set_string output_file, "Set output file name");
   ("--root", Arg.Set_string root, "Set the root path for all relative locations");
   ("--store-shapes", Arg.Set store_shapes, "Aggregate input-indexes shapes and store them in the new index");
   ("-I", Arg.String (fun arg -> build_path := arg::!build_path), "An extra directory to add to the load path");]


let set_log_level debug verbose =
  Log.set_log_level Error;
  if verbose then Log.set_log_level Warning;
  if debug then Log.set_log_level Debug

let () =
  Arg.parse speclist anon_fun usage_msg;
  set_log_level !debug !verbose;
  (match !command with
  | Some Aggregate ->
    let root = if String.equal "" !root then None else Some !root in
    Index.from_files ~store_shapes:!store_shapes ~root ~output_file:!output_file ~build_path:!build_path !input_files
  | Some Dump ->
      List.iter (fun file ->
      Merlin_index_format.Index_format.(read_exn ~file |> pp Format.std_formatter))
      !input_files
  | _ -> Printf.printf "Nothing to do.\n%!");
  exit 0
