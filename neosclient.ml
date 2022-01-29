(* OCaml Interface to the NEOS Servers

   2022 T. Bourke (Inria)

  See: https://neos-server.org/neos/xml-rpc.html
  and: https://neos-server.org/neos/solvers/lp:CPLEX/LP-help.html
 *)

type categories = {
  bco         : string;
  nco         : string;
  kestrel     : string;
  minco       : string;
  milp        : string;
  cp          : string;
  lp          : string;
  uco         : string;
  lno         : string;
  slp         : string;
  sdp         : string;
  co          : string;
  ndo         : string;
  sio         : string;
  ma          : string;
  go          : string;
  multi       : string [@key "MULTI"];
  socp        : string;
  miocp       : string;
  test        : string;
  application : string;
  mpec        : string;
  emp         : string;
} [@@deriving show, rpcty]

let unit_p = Idl.Param.mk Rpc.Types.unit
let string_p = Idl.Param.mk Rpc.Types.string
let string_array_p = Idl.Param.mk
  (Rpc.Types.{ name = "string array";
               description = ["Array of Strings"];
               ty = Array (Basic String) })
let categories_p = Idl.Param.mk categories

module NeosInterface(R : Idl.RPC) = struct
  open R

  (** {2:Retrieving information from NEOS} *)

  let help = declare "help"
    ["Show help"]
    (void (returning string_p Idl.DefaultError.err))

  let welcome = declare "welcome"
    ["Returns a welcome mesage"]
    (void (returning string_p Idl.DefaultError.err))

  let version = declare "version"
    ["Returns the version number of the NEOS server as a string"]
    (void (returning string_p Idl.DefaultError.err))

  let ping = declare "ping"
    ["Verifies that the NEOS server is running. Returns the message \
      'NEOS server is alive'"]
    (void (returning string_p Idl.DefaultError.err))

  let print_queue = declare "printQueue"
    ["Returns a string with a list of the current jobs on NEOS"]
    (void (returning string_p Idl.DefaultError.err))

  let get_solver_template = declare "getSolverTemplate"
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
    (void (returning string_array_p Idl.DefaultError.err))

  let list_categories = declare "listCategories"
    ["Lists all solver categories available onf NEOS, formated as a \
      dictionary with entries {'abbreviated name':'full name', ...}"]
    (void (returning categories_p Idl.DefaultError.err))

  let list_solvers_in_category = declare "listSolversInCategory"
    ["List all NEOS solvers in the specified category, formatted as \
      solver:input. The category can be the full name or the abbreviation"]
    (string_p @-> returning string_array_p Idl.DefaultError.err)

end

let server_url = Uri.of_string "https://neos-server.org:3333"

let rpc ~debug c =
  if debug then Printf.eprintf "sending:\n%s\n" (Xmlrpc.string_of_call c);
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
      if debug then
        Printf.eprintf "Response code: %d\nHeaders: %s\n"
          (Cohttp.Code.code_of_status (resp |> Cohttp.Response.status))
          (resp |> Cohttp.Response.headers |> Cohttp.Header.to_string);
    body |> Cohttp_lwt.Body.to_string >|= fun body ->
      if debug then Printf.eprintf "received:\n%s\n" body;
      Xmlrpc.response_of_string body
  in
  Lwt_main.run call_server

module NeosClient :
  sig
    val help : unit -> string

    val welcome : unit -> string

    val version : unit -> string

    val ping : unit -> string

    val print_queue : unit -> string

    val list_all_solvers : unit -> string array

    val get_solver_template : string -> string -> string -> string

    val list_categories : unit -> categories

    val list_solvers_in_category : string -> string array

  end = NeosInterface (Idl.Exn.GenClient (struct let rpc = rpc ~debug:true end))

(* let _ = print_string (NeosClient.help ()) *)
(* let _ = print_string (NeosClient.welcome ()) *)
(* let _ = print_endline (NeosClient.version ()) *)
(* let _ = print_string (NeosClient.ping ()) *)
(* let _ = print_string (NeosClient.print_queue ()) *)
(* let _ = Array.iter print_endline (NeosClient.list_all_solvers ()) *)
(* let _ = print_endline (show_categories (NeosClient.list_categories ())) *)
(* let _ = print_endline (NeosClient.get_solver_template "milp" "CPLEX" "LP") *)
(* let _ = Array.iter print_endline (NeosClient.list_solvers_in_category "milp") *)

