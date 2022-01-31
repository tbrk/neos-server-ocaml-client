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
    ["Returns a welcome mesage"]
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
      Xmlrpc.response_of_string body
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

let send_string s fd =
  let rec go remaining offset =
    if remaining > 0 then
      try
        let written = Unix.write_substring fd s offset remaining in
        go (remaining - written) (offset + written)
      with Unix.(Unix_error (EINTR, _, _)) -> go remaining offset
    else ()
  in
  go (String.length s) 0

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

let rec wait pid =
  try ignore (Unix.waitpid [] pid);
  with Unix.(Unix_error (EINTR, _, _)) -> wait pid

let unzip sz =
  let from_string, to_funzip = Unix.pipe ~cloexec:false () in
  let from_funzip, to_string = Unix.pipe ~cloexec:false () in
  let funzip = Unix.create_process "funzip" [| "funzip" |]
               from_string to_string Unix.stderr
  in
  Unix.close from_string;
  Unix.close to_string;
  match Unix.fork () with
  | 0 ->
      (* write the compressed string to the funzip process *)
      Unix.close from_funzip;
      Fun.protect ~finally:(fun () -> Unix.close to_funzip)
                  (fun () -> send_string sz to_funzip);
      exit 0
  | child ->
      (* read the uncompressed string from the funzip process *)
      Unix.close to_funzip;
      let cleanup () =
        Unix.close from_funzip;
        wait funzip;
        wait child
      in
      Fun.protect ~finally:cleanup (fun () -> recv_string from_funzip)

(* Using the interface *)

let email = ref ""
let category = ref "lp"
let solver = ref "CPLEX"
let comments = ref None
let lp_file = ref ""

let args = Arg.[
  ("--email", Set_string email,
   "A valid email address is required to submit a job");

  ("--server", Set_string server_url,
   "The URL of the NEOS server");

  ("--category", Set_string category,
   "The category of the request. Defaults to 'lp'");

  ("--solver", Set_string solver,
   "The solver to use. Defaults to 'CPLEX'");

  ("--comments", String (fun s -> comments := Some s),
   "Optional comments to send with the job.");

  ("--lp", Set_string lp_file,
   "Path to the lp file to solve.");
]

let slurp path =
  let fd = Unix.(openfile path [ O_RDONLY ] 0o640) in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> recv_string fd)

let poll_final_results jobnum passwd =
  let rec go () =
    Format.printf "checking@.";
    let s = Call.get_final_results_non_blocking jobnum passwd in
    if s = "" then (Format.printf "sleeping...@."; Unix.sleep 5; go ())
    else s
  in go ()

let main () =
  Arg.parse args (fun s -> lp_file := s) "neosclient.exe";
  if !email = ""
    then (Format.eprintf "An email address must be specified.@."; exit 1);
  if !lp_file = ""
    then (Format.eprintf "An lp file must be specified.@."; exit 2);
  Format.printf "%s@." (Call.ping ());
  let lp = slurp !lp_file in
  let job = lp_job ~category:!category ~solver:!solver ~email:!email ~lp
                   ~wantsol:true ?comments:!comments ()
  in
  let jobnum, passwd = Call.submit_job job in
  Format.printf "job= %d passwd= %s@." jobnum passwd;
  Unix.sleep 2;
  Format.printf "%s@." (Call.print_queue ());
  let log = poll_final_results jobnum passwd in
  Format.printf "%s@." log;
  let sz = Call.get_output_file jobnum passwd "solver-output.zip" in
  Format.printf "--------soln.sol:@.%s@." (unzip sz)

let _ = main ()

