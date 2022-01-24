
(*
  See: https://neos-server.org/neos/xml-rpc.html
  and: https://neos-server.org/neos/solvers/lp:CPLEX/LP-help.html
 *)

module NeosInterface(R : Idl.RPC) = struct
  open R

  let unit_p = Idl.Param.mk Rpc.Types.unit
  let string_p = Idl.Param.mk Rpc.Types.string

  (** {2:Retrieving information from NEOS} *)

  let help = declare "help"
    ["Show help"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let welcome = declare "welcome"
    ["Returns a welcome mesage"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let version = declare "version"
    ["Returns the version number of the NEOS server as a string"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let ping = declare "ping"
    ["Verifies that the NEOS server is running. Returns the message \
      'NEOS server is alive'"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let print_queue = declare "printQueue"
    ["Returns a string with a list of the current jobs on NEOS"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let get_solver_template = declare "get_solver_template"
    ["Returns a template for the requested solver for the particular \
      category and inputMethod provided. If the particular combination \
      of solver:category:solvername:inputMethod exists on NEOS, then this \
      function returns an XML template to use when submitting jobs via \
      XML-RPC or email"]
    (string_p @-> string_p @-> string_p
      @-> returning string_p Idl.DefaultError.err)

  let list_all_solvers = declare "listAllSolvers"
    ["Returns a list of all solvers available on NEOS, formated as \
      category:solver:inputMethod"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let list_categories = declare "listCategories"
    ["Lists all solver categories available onf NEOS, formated as a \
      dictionary with entries {'abbreviated name':'full name', ...}"]
    (unit_p @-> returning string_p Idl.DefaultError.err)

  let list_solvers_in_category = declare "listSolversInCategory"
    ["List all NEOS solvers in the specified category, formatted as \
      solver:input. The category can be the full name or the abbreviation"]
    (string_p @-> returning string_p Idl.DefaultError.err)

end

let server_url = Uri.of_string "https://neos-server.org:3333"

let rpc c =
  (*
  Printf.printf "sending:\n%s\n" (Xmlrpc.string_of_call c);
  *)
  let xml = Xmlrpc.string_of_call c in
  let body = Cohttp_lwt.Body.of_string xml in
  let headers = Cohttp.Header.of_list [
      ("content-type", "text/xml");
      ("content-length", Int.to_string (String.length xml));
    ]
  in
  let open Lwt in
  let call_server =
    Cohttp_lwt_unix.Client.post ~headers ~body server_url >>= fun (resp, body) ->
    let status = resp |> Cohttp.Response.status in
    let code = Cohttp.Code.code_of_status status in
    (*
    Printf.printf "Response code: %d\n" code;
    Printf.printf "Headers: %s\n" (resp
                                   |> Cohttp.Response.headers
                                   |> Cohttp.Header.to_string);
    *)
    body |> Cohttp_lwt.Body.to_string >|= fun body ->
    if code = 200 then Rpc.(success (String body))
                  else Rpc.(failure (String (Cohttp.Code.string_of_status status)))
  in
  Lwt_main.run call_server

module NeosClient :
  sig
    val help : unit -> string

    val welcome : unit -> string

    val version : unit -> string

    val ping : unit -> string

    val print_queue : unit -> string

    val get_solver_template : string -> string -> string -> string

    val list_all_solvers : unit -> string

    val list_categories : unit -> string

    val list_solvers_in_category : string -> string

  end = NeosInterface (Idl.Exn.GenClient (struct let rpc = rpc end))

let _ = print_endline (NeosClient.ping ())

