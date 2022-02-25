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

let int_p = Idl.Param.mk Rpc.Types.int
let unit_p = Idl.Param.mk Rpc.Types.unit
let string_p = Idl.Param.mk Rpc.Types.string
let string_array_p = Idl.Param.mk
  (Rpc.Types.{ name = "string array";
               description = ["Array of Strings"];
               ty = Array (Basic String) })
let pair_p (x, y) = Idl.Param.mk
  (Rpc.Types.{ name = "pair";
               description = ["Pair"];
               ty = Rpc.Types.Tuple (x, y) })
let int_string_pair_p = pair_p Rpc.Types.(Basic Int, Basic String)
let base64_int_pair_p = pair_p Rpc.Types.(Base64, Basic Int)
let categories_p = Idl.Param.mk categories
let base64_p = Idl.Param.mk
  (Rpc.Types.{ name = "base64";
               description = ["base64 encoded data"];
               ty = Base64 })

module NeosInterface(R : Idl.RPC) = struct
  open R

  (** {2:Retrieving information from NEOS} *)

  let help = declare "help"
    ["Show help"]
    (noargs (returning string_p Idl.DefaultError.err))

  let welcome = declare "welcome"
    ["Returns a welcome message"]
    (noargs (returning string_p Idl.DefaultError.err))

  let version = declare "version"
    ["Returns the version number of the NEOS server as a string"]
    (noargs (returning string_p Idl.DefaultError.err))

  let ping = declare "ping"
    ["Verifies that the NEOS server is running. Returns the message \
      'NEOS server is alive'"]
    (noargs (returning string_p Idl.DefaultError.err))

  let print_queue = declare "printQueue"
    ["Returns a string with a list of the current jobs on NEOS"]
    (noargs (returning string_p Idl.DefaultError.err))

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
    (noargs (returning string_array_p Idl.DefaultError.err))

  let list_categories = declare "listCategories"
    ["Lists all solver categories available onf NEOS, formated as a \
      dictionary with entries {'abbreviated name':'full name', ...}"]
    (noargs (returning categories_p Idl.DefaultError.err))

  let list_solvers_in_category = declare "listSolversInCategory"
    ["List all NEOS solvers in the specified category, formatted as \
      solver:input. The category can be the full name or the abbreviation"]
    (string_p @-> returning string_array_p Idl.DefaultError.err)

  (** {2:Submitting Jobs and Retrieving Results from NEOS} *)

  let submit_job = declare "submitJob"
    ["Submits an optimization job to NEOS. These methods will return \
      a tuple (jobnumber, password). The returned job number and password \
      can be used to get the status of the job or the results of the job. \
      If there is any error (e.g., the NEOS job queue is full), the method \
      will return the tuple (0, errorMessage). Information on the xmlstring \
      format can be retrieved via the getSolverTemplate() function"]
    (string_p @-> returning int_string_pair_p Idl.DefaultError.err)

  let authenticated_submit_job = declare "authenticatedSubmitJob"
    ["Submits an optimization job to NEOS using a specific account"]
    (string_p @-> string_p @-> string_p
      @-> returning int_string_pair_p Idl.DefaultError.err)

  let get_job_status = declare "getJobStatus"
    ["Gets the current status of the job. Returns \"Done\", \"Running\", \
      \"Waiting\", \"Unknown Job\", or \"Bad Password\""]
    (int_p @-> string_p @-> returning string_p Idl.DefaultError.err)

  let get_completion_code = declare "getCompletionCode"
    ["Gets the completion code for \"Done\" jobs; result is undefined for \
      jobs that are \"Waiting\" or \"Running\". Returns \"Normal\", \
      \"Out of memory\", \"Timed out\", \"Disk Space\", \"Server error\", \
      \"Unknown Job\", or \"Bad Password\""]
    (int_p @-> string_p @-> returning string_p Idl.DefaultError.err)

  let get_job_info = declare "getJobInfo"
    ["Gets information on the job. Returns a tuple \
      [(category, solver_name, input, status, completion_code)]"]
    (int_p @-> string_p @-> returning string_array_p Idl.DefaultError.err)

  let kill_job = declare "killJob"
    ["Cancel a submitted job that is running or waiting to run on NEOS. \
      The job password is required to prevent abuse of this function"]
    (int_p @-> string_p @-> string_p
      @-> returning string_p Idl.DefaultError.err)

  let get_final_results = declare "getFinalResults"
    ["Retrieve results from a submitted job on NEOS. If the job is still \
      running, then this function will hang until the job is finished."]
    (int_p @-> string_p @-> returning base64_p Idl.DefaultError.err)

  let email_job_results = declare "emailJobResults"
    ["Results for a finished job will be emailed to the email address \
      specified in the job submission. If results are too large for email, \
      they will not be emailed (though they can be accessed via the NEOS \
      website"]
    (int_p @-> string_p @-> returning string_p Idl.DefaultError.err)

  let get_intermediate_results = declare "getIntermediateResults"
    ["Gets intermediate results of a job submitted to NEOS, starting at \
      the specified character offset up to the last received data. \
      Intermediate results are usually the standard output of the solver \
      daemon. Note that because output does not stream for jobs with \
      \"long\" priority (default value), [getIntermediateResults()] will \
      not return any results for long priority jobs. Output does stream \
      for jobs with \"short\" priority (maximum time of 5 minutes).\
      If the job is still running, then this function will hang until \
      another packet of output is sent to NEOS or the job is finished. This \
      function will return a tuple of the base-64 encoded object and the \
      new offset [(object, newoffset)]. The offset refers to uncoded \
      characters."]
    (int_p @-> string_p @-> int_p
      @-> returning base64_int_pair_p Idl.DefaultError.err)

  let get_final_results_non_blocking = declare "getFinalResultsNonBlocking"
    ["Gets results of a job submitted to NEOS (non-blocking). If the job \
      is still running, then this function will return an empty string."]
    (int_p @-> string_p @-> returning base64_p Idl.DefaultError.err)

  let get_intermediate_results_non_blocking = declare "getIntermediateResultsNonBlocking"
    ["Gets intermediate results of a job submitted to NEOS together with \
      the new offset. The offset refers to the uncoded characters. \
      Intermediate results are usually the standard output of the solver \
      daemon. Note that because output does not stream for jobs with \
      \"long\" priority (default value), getIntermediateResults() will \
      not return any results for long priority jobs. Output does stream \
      for jobs with \"short\" priority (maximum time of 5 minutes)."]
    (int_p @-> string_p @-> int_p
      @-> returning base64_int_pair_p Idl.DefaultError.err)

  let get_output_file = declare "getOutputFile"
    ["Retrieve a named output file from NEOS where fileName is one of the \
      following: 'results.txt', 'ampl.sol', 'solver-output.zip', 'job.in', \
      'job.out', 'job.results'. Note: the existence of a given file may \
      depend on the solver or options selected when the job is started. \
      If the job is still running, then this function will block until \
      the job is finished."]
    (int_p @-> string_p @-> string_p @-> returning base64_p Idl.DefaultError.err)
end

let server_url = ref "https://neos-server.org:3333"

let base64_2045_decode s =
  let open Base64_rfc2045 in
  let buf = Buffer.create 1024 in
  let d = decoder (`String s) in
  let rec go () =
    match decode d with
    | `Flush s -> (Buffer.add_string buf s; go ())
    | `End -> Buffer.contents buf
    (* best-effort *)
    | `Malformed _   (* ignore; usually missing '\r' before '\n' *)
    | `Wrong_padding (* ignore *)
    | `Await -> go ()
  in
  go ()

(* Send request over https and decode the resonse. *)
let rpc ~debug c =
  if debug then Printf.eprintf "sending:\n%s\n" (Xmlrpc.string_of_call c);
  let xml = Xmlrpc.string_of_call ~strict:true c in
  let body = Cohttp_lwt.Body.of_string xml in
  let headers = Cohttp.Header.of_list [
      ("content-type", "text/xml");
      ("content-length", Int.to_string (String.length xml));
    ]
  in
  let open Lwt in
  let call_server =
    Cohttp_lwt_unix.Client.post ~headers ~body
        (Uri.of_string !server_url) >>= fun (resp, body) ->
      if debug then
        Printf.eprintf "Response code: %d\nHeaders: %s\n"
          (Cohttp.Code.code_of_status (resp |> Cohttp.Response.status))
          (resp |> Cohttp.Response.headers |> Cohttp.Header.to_string);
    body |> Cohttp_lwt.Body.to_string >|= fun body ->
      if debug then Printf.eprintf "received:\n%s\n" body;
      Xmlrpc.response_of_string ~base64_decoder:base64_2045_decode body
  in
  Lwt_main.run call_server

module Call :
  sig
    (** {2:Retrieving information from NEOS} *)

    val help : unit -> string

    val welcome : unit -> string

    val version : unit -> string

    val ping : unit -> string

    val print_queue : unit -> string

    val list_all_solvers : unit -> string array

    val get_solver_template : string -> string -> string -> string

    val list_categories : unit -> categories

    val list_solvers_in_category : string -> string array

    (** {2:Submitting Jobs and Retrieving Results from NEOS} *)

    val submit_job : string -> int * string

    (* [authenticated_submit_job job username password] *)
    val authenticated_submit_job : string -> string ->string -> int * string

    val get_job_status : int -> string -> string

    val get_completion_code : int -> string -> string

    val get_job_info : int -> string -> string array

    val kill_job : int -> string -> string -> string

    val get_final_results : int -> string -> string

    val email_job_results : int -> string -> string

    val get_intermediate_results : int -> string -> int -> string * int

    val get_final_results_non_blocking : int -> string -> string

    val get_intermediate_results_non_blocking : int -> string -> int -> string * int

    val get_output_file : int -> string -> string -> string

  end = NeosInterface (Idl.Exn.GenClient (struct let rpc = rpc ~debug:false end))

(* XML template for LP format *)

let pp_opt_cdata pp_data pp = function
  | None -> ()
  | Some data -> Format.fprintf pp "<![CDATA[@,%a@,]]>" pp_data data

let pp_lp_job pp ~category ~solver ~email ~pplp ~lp ?(short_priority=false)
      ?(options="") ?(post="") ?bas ?mst ?sol
      ?(wantbas=false) ?(wantmst=false) ?(wantsol=false) ?(comments="") () =
  let open Format in
  fprintf pp "@[<v><document>@,";
  fprintf pp "<category>%s</category>@," category;
  fprintf pp "<solver>%s</solver>@," solver;
  fprintf pp "<inputMethod>LP</inputMethod>@,";
  fprintf pp "<priority>%s</priority>@,"
    (if short_priority then "short" else "long");
  fprintf pp "<email>%s</email>@," email;
  fprintf pp "<LP><![CDATA[%a@,]]></LP>@," pplp lp;
  fprintf pp "<options><![CDATA[@,%s@,]]></options>@," options;
  fprintf pp "<post><![CDATA[@,%s@,]]></post>@," post;
  fprintf pp "<BAS>%a</BAS>@," (pp_opt_cdata pp_print_string) bas;
  fprintf pp "<MST>%a</MST>@," (pp_opt_cdata pp_print_string) mst;
  fprintf pp "<SOL>%a</SOL>@," (pp_opt_cdata pp_print_string) sol;
  if wantbas then fprintf pp "<wantbas>yes</wantbas>@,";
  if wantmst then fprintf pp "<wantmst>yes</wantmst>@,";
  if wantsol then fprintf pp "<wantsol>yes</wantsol>@,";
  fprintf pp "<comments><![CDATA[@,%s@,]]></comments>@," comments;
  fprintf pp "</document>@]"

let lp_job ~category ~solver ~email ~lp ?short_priority
      ?options ?post ?bas ?mst ?sol ?wantbas ?wantmst ?wantsol ?comments () =
  let buf = Buffer.create 1024 in
  let pp = Format.formatter_of_buffer buf in
  pp_lp_job pp ~category ~solver ~email ~pplp:Format.pp_print_string ~lp
      ?short_priority ?options ?post ?bas ?mst ?sol
      ?wantbas ?wantmst ?wantsol ?comments ();
  Format.pp_print_flush pp ();
  Buffer.contents buf

(* Unzip returned data using forked [funzip] *)

let funzip ~ipath ~opath =
  let f = Zip.open_in ipath in
  Zip.(copy_entry_to_file f (List.hd (entries f)) opath);
  Zip.close_in f

(* Utilities *)

let datetime Unix.{ tm_year; tm_mon; tm_mday; tm_hour; tm_min; _ } =
  Format.sprintf "%04d-%02d-%02d_%02d%02d"
    (tm_year + 1900) (tm_mon + 1) tm_mday tm_hour tm_min

(* Using the interface *)

let email = ref ""
let jobname = ref (datetime Unix.(localtime (time ())))
let solver = ref "CPLEX"

let lp_options = ref (None : string option)

let job = ref 0
let password = ref ""

let show_waiting = ref true
let poll_interval = ref 60

let check_job () =
  if !job = 0 || !password = "" then
    (Format.eprintf "Must specify --job and --password@."; exit 1)

let show_queue () = Format.printf "%s@?" (Call.print_queue ())
let send_ping () = Format.printf "%s@?" (Call.ping ())
let do_sleep d = Unix.sleep d

let kill_job () =
  check_job ();
  Format.printf "%s@." (Call.kill_job !job !password "")

let job_status () =
  check_job ();
  Format.printf "job status: %s@." (Call.get_job_status !job !password)

let job_info () =
  check_job ();
  let r = Call.get_job_info !job !password in
  Format.printf
    "job info: category=%s solver_name=%s input=%s status=%s@."
    r.(0) r.(1) r.(2) r.(3)

let recv_string fd =
  let buffer = Buffer.create 1024 in
  let b = Bytes.create 1024 in
  let rec go () =
    try
      let n = Unix.read fd b 0 1024 in
      if n = 0 then Buffer.contents buffer
      else (Buffer.add_subbytes buffer b 0 n; go ())
      with Unix.(Unix_error (EINTR, _, _)) -> go ()
  in
  go ()

let slurp path =
  let fd = Unix.(openfile path [ O_RDONLY ] 0o640) in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> recv_string fd)

let send_string fd s =
  let rec go remaining offset =
    if remaining > 0 then
      try
        let written = Unix.write_substring fd s offset remaining in
        go (remaining - written) (offset + written)
      with Unix.(Unix_error (EINTR, _, _)) -> go remaining offset
    else ()
  in
  go (String.length s) 0

let dump path s =
  let fd = Unix.(openfile path [ O_WRONLY; O_CREAT; O_TRUNC ] 0o666) in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> send_string fd s)

let handle_lp_file path =
  if !email = ""
    then (Format.eprintf "Sending an lp file requires an email address.@.";
          exit 1);
  let j, pw = Call.submit_job
                (lp_job ~category:"lp" ~solver:!solver ~email:!email
                        ~lp:(slurp path) ?options:!lp_options ~wantsol:true ())
  in
  job := j;
  password := pw;
  Format.printf "%s --job %d --password %s --status@."
    Sys.argv.(0) !job !password

let handle_file path =
  if Filename.extension path = ".lp" then handle_lp_file path
  else (Format.eprintf "unknown file type: %s@." (Filename.basename path); exit 1)
let re_has_solution = Str.regexp "solution written to file 'soln.sol'"

let poll_results () =
  let add_newline = ref false in
  let rec go () =
    let log = Call.get_final_results_non_blocking !job !password in
    if log <> "" then begin
      if !add_newline then Format.print_newline ();
      let logpath = !jobname ^ ".log" in
      dump logpath log;
      Format.printf "log written to: %s@." logpath;
      match Str.search_forward re_has_solution log 0 with
      | _ ->
          let zippath = !jobname ^ ".zip" in
          let solpath = !jobname ^ ".xml" in
          let solz = Call.get_output_file !job !password "solver-output.zip" in
          dump zippath solz;
          funzip ~ipath:zippath ~opath:solpath;
          Unix.unlink zippath;
          Format.printf "solution written to: %s@." solpath;
          exit 0
      | exception Not_found ->
          Format.printf "no solution found@.";
          exit (-1)
    end
    else begin
      if !show_waiting then (Format.printf ".@?"; add_newline := true);
      Unix.sleep !poll_interval;
      go ()
    end
  in
  check_job ();
  go ()

let args = Arg.(align [
  ("--email", Set_string email,
   "<string> A valid email address is required to submit a job");

  ("--jobname", Set_string jobname,
   "<string> Used to name log and solution files.");

  ("--server", Set_string server_url,
   "<url> The URL of the NEOS server (" ^ !server_url ^ ")");

  ("--solver", Set_string solver,
   "<string> The solver to use (" ^ !solver ^ ")");

  ("--job", Set_int job, "<int> The current job number");
  ("--password", Set_string password, "<string> The current password");

  ("--lp-options", String (fun s -> lp_options := Some s),
   "Options to set before running the jobs");

  ("--sleep", Int do_sleep, "<int> Sleep for a given number of seconds");
  ("--queue", Unit show_queue, " Show the server queue");
  ("--ping", Unit send_ping, " Ping the server");

  ("--kill", Unit kill_job, " Kill a job");
  ("--status", Unit job_status, " Get job status");
  ("--info", Unit job_info, " Get information on a job");

  ("--poll", Unit poll_results,
   " Wait for the job to complete and download the results.");
  ("--poll-interval", Set_int poll_interval,
   "<int> Set the interval in seconds for polling.");
  ("--quiet", Clear show_waiting, " Do not show '.'s while polling.");
])

let usage_msg =
  (Filename.basename Sys.argv.(0)) ^
    ": submit and manage jobs on the NEOS Server"

let _ = Arg.parse args handle_file usage_msg

(* example 1
    ./runneos --email me@ problem.lp --poll

   example 2
    ./runneos --queue

   example 3
    ./runneos --email me@ --ping problem.lp
    ./runneos --job <jobnum> --password <password> --status
    ./runneos --job <jobnum> --password <password> --info
    ./runneos --job <jobnum> --password <password> --kill
 *)

