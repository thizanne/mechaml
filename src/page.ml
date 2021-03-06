(*{{{ Copyright (C) 2016, Yann Hamdaoui <yann.hamdaoui@centraliens.net>
  Permission to use, copy, modify, and/or distribute this software for any
  purpose with or without fee is hereby granted, provided that the above
  copyright notice and this permission notice appear in all copies.

  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
  REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
  AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
  INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
  OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
  TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
  THIS SOFTWARE.
  }}}*)

type t = { base_uri : Uri.t; soup : Soup.soup Soup.node }

type elt = Soup.element Soup.node

open Option.Infix

let id x = x

let is_identifier_char c =
  let code = c |> Char.lowercase_ascii |> Char.code in
  (code >= (Char.code 'a') && code <= (Char.code 'z')) ||
  (code >= (Char.code '0') && code <= (Char.code '9')) ||
  (c == '-') || (c == '_')

let tag_filter tag node =
  Soup.name node = tag

let input_filter input_type node =
  Soup.name node = "input"
  && (Soup.attribute "type" node >|= fun t ->
    t=input_type) |? false

let is_input_field = function
  | "text"
  | "password"
  | "hidden" -> true
  | _ -> false

let is_input_numeric = function
  | "range"
  | "number" -> true
  | _ -> false

let numeric_filter node =
  Soup.attribute "type" node
  >|= is_input_numeric
  |? false

let field_filter node =
  match Soup.name node with
    | "textarea" -> true
    | "input" ->
      Soup.attribute "type" node >|= is_input_field |? false
    | _ -> false

let tag_selector tag = function
  | "" -> tag
  | s when s.[0]='*' -> s
  | s when is_identifier_char s.[0] -> s
  | s -> tag^s

let from_soup ?(location=Uri.empty) soup =
  let base_uri =
    Soup.select_one "base[href]" soup
    >>= Soup.attribute "href"
    >|= Uri.of_string |? location in
  {base_uri; soup}

let from_string ?(location=Uri.empty) s =
  s
  |> Soup.parse
  |> from_soup ~location

let base_uri p = p.base_uri

let resolver p = Uri.resolve "" p.base_uri

let soup p = p.soup

type +'a seq = { eliminate : 'b. ('b -> 'a -> 'b) -> 'b -> 'b }
type 'a stop = 'a Soup.stop = { throw : 'b. 'a -> 'b }

let with_stop = Soup.with_stop

let seq_from_nodes gen nodes =
  { eliminate = fun f init ->
      let f' acc x = f acc (gen x) in
      Soup.fold f' init nodes }

let iter it seq =
  seq.eliminate (fun _ -> it) ()

let fold f init seq = seq.eliminate f init

let filter pred seq =
  { eliminate = fun f init ->
      let f' acc x = if pred x then f acc x else acc in
      seq.eliminate f' init }

let nth n seq =
  with_stop (fun stop ->
    seq.eliminate (fun i x ->
      if i = n then Some x |> stop.throw
      else i+1) 1
    |> ignore;
    None)

let first seq = nth 1 seq

let find_first pred seq =
  seq
  |> filter pred
  |> first

let to_list seq =
  seq.eliminate (fun l x -> x::l) []
  |> List.rev

module Form = struct
  module StringMap = Map.Make(String)

  type t = {resolver : Uri.t -> Uri.t; elt : elt; data : (string list) StringMap.t}

  type checkbox
  type radio_button
  type select_list
  type menu
  type field

  type _ input = elt
  type _ inputs = Soup.element Soup.nodes

  let name f = Soup.attribute "name" f.elt

  let action f =
    f.elt
    |> Soup.attribute "action"
    >|= Uri.of_string
    |> Soup.require

  let uri f =
    f
    |> action
    |> f.resolver

  let meth f =
    let m = f.elt
      |> Soup.attribute "method"
      >|= String.lowercase_ascii
      >|= String.trim in
    match m with
      | Some "post" -> `POST
      | _ -> `GET

  let to_node f = f.elt
  let input_to_node i = i

  let set_multi key values f =
    {f with data = f.data |> StringMap.add key values}
  let set key value f = set_multi key [value] f

  let get_multi key f = StringMap.find key f.data
  let get key f =
    get_multi key f
    |> (function
      | [] -> None
      | x::xs -> Some x)

  let clear key f =
    {f with data = f.data |> StringMap.remove key}
  let reset = clear

  let clear_all f =
    {f with data = StringMap.empty }

  let values f = StringMap.fold (fun id value l -> (id,value)::l) f.data []

  let _inputs_with input selector f =
    let default_selector = Printf.sprintf "input[type=%s]" input in
    f.elt
    |> Soup.select (tag_selector default_selector selector)
    |> Soup.filter (input_filter input)
    |> seq_from_nodes id

  let _input_with input selector f =
    f
    |> _inputs_with input selector
    |> first

  let _inputs input f =
    _inputs_with input "" f

  let checkboxes_with = _inputs_with "checkbox"
  let checkbox_with = _input_with "checkbox"
  let checkboxes = _inputs "checkbox"

  let radio_buttons_with = _inputs_with "radio"
  let radio_button_with = _input_with "radio"
  let radio_buttons = _inputs "radio"

  let select_lists_with selector f =
    f.elt
    |> Soup.select (tag_selector "select" selector)
    |> Soup.filter (tag_filter "select")
    |> seq_from_nodes id

  let select_list_with selector f =
    f
    |> select_lists_with selector
    |> first

  let select_lists = select_lists_with ""

  let fields_with selector f =
    f.elt
    |> Soup.select (tag_selector "*" selector)
    |> Soup.filter field_filter
    |> seq_from_nodes id

  let field_with selector f =
    f
    |> fields_with selector
    |> first

  let fields = fields_with ""

  let numerics_with selector f =
    f.elt
    |> Soup.select (tag_selector "input" selector)
    |> Soup.filter numeric_filter
    |> seq_from_nodes id

  let numeric_with selector f =
    f
    |> numerics_with selector
    |> first

  let numerics = numerics_with ""

  let texts_with = _inputs_with "text"
  let text_with = _input_with "text"
  let texts = _inputs "text"

  let passwords_with = _inputs_with "password"
  let password_with = _input_with "password"
  let passwords =  _inputs "password"

  let hiddens_with = _inputs_with "hidden"
  let hidden_with = _input_with "hidden"
  let hiddens = _inputs "hidden"

  let textareas_with selector f =
    f.elt
    |> Soup.select (tag_selector "textarea" selector)
    |> Soup.filter (fun node -> Soup.name node = "textarea")
    |> seq_from_nodes id

  let textarea_with selector f =
    f |> textareas_with selector |> first

  let textareas = textareas_with ""

  let colors_with = _inputs_with "color"
  let color_with = _input_with "color"
  let colors = _inputs "color"

  let dates_with = _inputs_with "date"
  let date_with = _input_with "date"
  let dates = _inputs "date"

  let emails_with = _inputs_with "email"
  let email_with = _input_with "email"
  let emails = _inputs "email"

  let months_with = _inputs_with "month"
  let month_with = _input_with "month"
  let months = _inputs "month"

  let numbers_with = _inputs_with "number"
  let number_with = _input_with "number"
  let numbers = _inputs "number"

  let tels_with = _inputs_with "tel"
  let tel_with = _input_with "tel"
  let tels = _inputs "tel"

  let searchs_with = _inputs_with "search"
  let search_with = _input_with "search"
  let searchs = _inputs "search"

  let times_with = _inputs_with "time"
  let time_with = _input_with "time"
  let times = _inputs "time"

  let urls_with = _inputs_with "url"
  let url_with = _input_with "url"
  let urls = _inputs "url"

  let iname input = Soup.attribute "name" input
  let ivalue input = Soup.attribute "value" input

  let singleton x = [x]
  let cons x l = x::l
  let uncurry f (x,y) = f x y

  (* flipped versions of functions on maps *)
  let map_add m k v = StringMap.add k v m
  let map_remove m k = StringMap.remove k m
  let map_find m k = StringMap.find k m

  let update_form f newdata = {f with data = newdata |? f.data}

  let has_value m k v =
    try
      map_find m k
      |> List.mem v
    with Not_found -> false

  let current_values m k =
    try
      map_find m k
    with Not_found -> []

  let add_value m k v =
    v::(current_values m k)
    |> map_add m k

  let rem_value m k v =
    current_values m k
    |> List.filter ((<>) v)
    |> map_add m k

  let current_value m k =
    match map_find m k with
      | exception Not_found -> None
      | [x] -> Some x
      | _ -> None

  let reset_single f input get_default =
    match iname input, get_default f input with
      | None, _ -> f
      | Some name, None -> clear name f
      | Some name, Some value -> set name value f

  let reset_multi f input get_default =
    match iname input, get_default f input with
      | None, _ -> f
      | Some name, [] -> clear name f
      | Some name, values -> set_multi name values f

  module Checkbox = struct
    let cb_selector name = Printf.sprintf "[type=checkbox][name=%s]" name

    let value cb = ivalue cb |> Soup.require

    let choices f cb =
      iname cb
      >|= cb_selector
      >|= (fun s ->
        Soup.select s f.elt)
      |> Soup.require
      |> seq_from_nodes id

    let values f cb =
      choices f cb |> fold (fun l cb ->
        match ivalue cb with
          | Some v -> v::l
          | None -> l) []

    let checked f cb =
      iname cb >|= current_values f.data |? []

    let check f cb =
      (iname cb, ivalue cb) >>> add_value f.data
      |> update_form f

    let uncheck f cb =
      (iname cb, ivalue cb) >>> rem_value f.data
      |> update_form f

    let is_checked f cb =
      (iname cb, ivalue cb) >>> has_value f.data |? false

    let checked_default f cb =
      choices f cb
      |> fold (fun values cb ->
        if Soup.has_attribute "checked" cb then
          (ivalue cb |? "on")::values
        else
          values) []
      |> List.rev

    let reset f cb = reset_multi f cb checked_default
  end

  module RadioButton = struct
    let rb_selector name = Printf.sprintf "[type=radio][name=%s]" name

    let value rb = ivalue rb |> Soup.require

    let choices f rb =
      iname rb
      >|= rb_selector
      >|= (fun s ->
        Soup.select s f.elt)
      |> Soup.require
      |> seq_from_nodes id

    let values f rb =
      choices f rb |> fold (fun l cb ->
        match ivalue cb with
          | Some v -> v::l
          | None -> l) []

    let selected f rb =
      iname rb >>= current_value f.data

    let select f rb =
      (iname rb, ivalue rb >|= singleton)
      >>> map_add f.data
      |> update_form f

    let is_selected f rb =
      (iname rb, ivalue rb) >>> has_value f.data |? false

    let selected_default f rb =
      with_stop (fun stop ->
        choices f rb
        |> iter (fun rb' ->
          if Soup.has_attribute "checked" rb' then
            Some (ivalue rb' |? "on")
            |> stop.throw);
        None)

    let reset f rb = reset_single f rb selected_default
  end

  module SelectList = struct
    type item = elt

    let items sl = Soup.select "option" sl |> Soup.to_list

    let is_multiple = Soup.has_attribute "multiple"

    let selected f sl =
      iname sl
      >|= current_values f.data |? []

    let unselect f sl item =
      iname sl
      >|= map_remove f.data
      |> update_form f

    let is_selected f sl item =
      (iname sl, ivalue item) >>> has_value f.data |? false

    let text item =
      item |> Soup.leaf_text |? ""

    let value item =
      item
      |> ivalue |? text item

    let select f sl item =
      iname sl
      >|= (function name ->
        let v = value item in
        if is_multiple sl then
          let vs = current_values f.data name in
          (if has_value f.data name v then vs else v::vs)
          |> map_add f.data name
        else
          map_add f.data name [v])
      |> update_form f

    let selected_default f sl =
      items sl
      |> List.fold_left (fun values item ->
        if Soup.has_attribute "selected" item then
          (value item)::values
        else
          values) []
      |> List.rev

    let reset f sl = reset_multi f sl selected_default
  end

  module Field = struct
    let fset = set

    let set f fd v =
      iname fd
      >|= (fun name ->
        map_add f.data name [v])
      |> update_form f

    let get f fd =
      iname fd >>= current_value f.data

    let default_value _ fd =
      match Soup.name fd with
        | "textarea" -> Soup.leaf_text fd
        | _ -> ivalue fd

    let reset f fd = reset_single f fd default_value
  end

  (* module FileUpload = struct *)
  (*   let select f fu path = *)
  (*     iname fu *)
  (*     >|= (fun name -> map_add f.data name [path]) *)
  (*     |> update_form f *)
  (*  *)
  (*   let which_selected f fu = *)
  (*     iname fu >>= current_value f.data *)
  (* end *)

  let reset_all f =
    checkboxes f
    |> fold Checkbox.reset f
    |> fun newf ->
    radio_buttons newf
    |> fold RadioButton.reset newf
    |> fun newf ->
    select_lists newf
    |> fold SelectList.reset newf
    |> fun newf ->
    fields newf
    |> fold Field.reset newf
end

module Link = struct
  type t = { resolver : Uri.t -> Uri.t ; elt : elt }

  let href link = link.elt |> Soup.attribute "href" |> Soup.require
  let text link = Soup.leaf_text link.elt
  let uri link = link |> href
    |> Uri.of_string
    |> link.resolver

  let to_node link = link.elt
end

module Image = struct
  type t = {resolver : Uri.t -> Uri.t ; elt : elt}

  let source image = image.elt |> Soup.attribute "src" |> Soup.require
  let uri image = image |> source
    |> Uri.of_string
    |> image.resolver

  let to_node image = image.elt
end

let forms_with selector p =
  p.soup
  |> Soup.select (tag_selector "form" selector)
  |> Soup.filter (tag_filter "form")
  |> seq_from_nodes (fun elt -> Form.( {resolver = resolver p; elt;
    data = StringMap.empty} |> reset_all ))

let forms = forms_with ""

let form_with selector p =
  p
  |> forms_with selector
  |> first

let links_with selector p =
  p.soup
  |> Soup.select (tag_selector "a" selector)
  |> Soup.filter (tag_filter "a")
  |> seq_from_nodes (fun elt -> Link.( {resolver = resolver p; elt} ))

let links = links_with ""

let link_with selector p =
  p
  |> links_with selector
  |> first

let images_with selector p =
  p.soup
  |> Soup.select (tag_selector "img" selector)
  |> Soup.filter (tag_filter "img")
  |> seq_from_nodes (fun elt -> Image.( {resolver = resolver p; elt} ))

let images = images_with ""

let image_with selector p =
  p
  |> images_with selector
  |> first
