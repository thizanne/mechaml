(* This file is in the public domain *)

(** Connect to https://ocaml.org/index.fr.html and download all the png images
   of the page in /tmp *)

open Mechaml
module M = Agent.Monad
open M.Infix

type state = Ok of string | Error of string * exn

let image_filename src =
  let last_slash = match String.rindex src '/' with
    | exception Not_found -> 0
    | i -> i+1 in
  String.sub src last_slash (String.length src - last_slash)

let save_images images =
  images
  |> M.List.map_p (fun img ->
    let path = Page.Image.source img
      |> image_filename
      |> (^) "/tmp/" in
    let save _ =
      Agent.save_image path img
      >> M.return (Ok path) in
    let handler e =
      Error (path,e)
      |> M.return in
    M.catch save handler)

let action_download =
  Agent.get "https://ocaml.org/index.fr.html"
  >|= (fun response ->
    response
    |> Agent.HttpResponse.page
    |> Page.images_with "[src$=.png]"
    |> Page.to_list)
  >>= save_images

let _ =
  action_download
  |> M.run (Agent.init ())
  |> snd
  |> List.iter (function
    | Ok file ->
      Printf.printf "Image %s successfully downloaded\n" file
    | Error (file,e) ->
      e
      |> Printexc.to_string
      |> Printf.printf "Image %s : error (%s)\n" file)
