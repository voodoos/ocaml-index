open Lib
open Cmdliner

module Common = struct
  let set_log_level debug verbose continue =
    Log.set_log_level Error;
    if verbose then Log.set_log_level Warning;
    if debug then Log.set_log_level Debug;
    continue

  let verbose =
    let doc = "increase log verbosity" in
    Arg.(value & flag & info [ "v"; "verbose" ] ~doc)

  let debug =
    let doc = "set maximum log verbosity" in
    Arg.(value & flag & info [ "debug" ] ~doc)

  let with_log t = Term.(const set_log_level $ debug $ verbose $ t)

  let output_file =
    let doc = "name of the generated index" in
    Arg.(
      value
      & opt string (Arg.doc_quote "project.index")
      & info [ "o"; "output-file" ] ~doc)
end

module Aggregate = struct
  let from_files store_shapes root output_file build_path file =
    Uideps.from_files ~store_shapes ~root ~output_file ~build_path file

  let root =
    let doc = "if provided all locations will be appended to that path" in
    Arg.(value & opt (some string) None & info [ "root" ] ~doc)

  let cmt_file =
    let doc = "the $(i, .cmt) file to be indexed" in
    Arg.(required & pos 0 (some string) None & info [] ~doc)

  let files =
    let doc = "the files to index" in
    Arg.(non_empty & pos_all string [] & info [] ~doc)

  let build_path =
    let doc = "the extra build path" in
    Arg.(value & pos_right 0 string [] & info [] ~doc)

  let store_shapes =
    let doc =
      "aggregate input-indexes shapes and store them in the new index"
    in
    Arg.(value & flag & info [ "store-shapes" ] ~doc)

  let term =
    Term.(
      const from_files $ store_shapes $ root $ Common.output_file $ build_path
      $ files)

  let cmd =
    let info =
      let doc = "builds the index for a single $(i, .cmt) file" in
      Cmd.info "aggregate" ~doc
    in
    Cmd.v info (Common.with_log term)
end

module Dump = struct
  let dump file = File_format.(read_exn ~file |> pp Format.std_formatter)

  let file =
    let doc = "the file to dump" in
    Arg.(required & pos 0 (some string) None & info [] ~doc)

  let term = Term.(const dump $ file)

  let cmd =
    let info =
      let doc = "print the content of an index file to stdout" in
      Cmd.info "dump" ~doc
    in
    Cmd.v info term
end

let subcommands =
  let info =
    let doc = "An indexer for OCaml's artifacts" in
    Cmd.info "ocaml-uideps" ~doc
  in
  Cmd.group info ~default:Aggregate.term [ Aggregate.cmd; Dump.cmd ]

let () = exit (Cmd.eval subcommands)
