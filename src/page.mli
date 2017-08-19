(*{{{ Copyright (C) 2016, Yann Hamdaoui <yann.hamdaoui@centraliens.net>
  Permission to use, copy, modify, and/or distribute this software for
  any purpose with or without fee is hereby granted, provided that the
  above copyright notice and this permission notice appear in all
  copies.
  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
  WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
  AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
  CONSEQUENTIAL
  DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
  DATA
  OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
  OTHER
  TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
  USE OR
  PERFORMANCE OF THIS SOFTWARE.
  }}}*)

(** Page

    This module contains all the functions used to analyze a page, select specific
    elements, and manage forms.

*)

(** The type of an html page *)
type t

(** Make a new page from a base URI and a Lambdasoup document *)
val from_soup : ?location:Uri.t -> Soup.soup Soup.node -> t
(** Make a new page from a base URI and a HTML string *)
val from_string : ?location:Uri.t -> string -> t

(** Return the location of a page (or [Uri.empty] if not specified) *)
val base_uri : t -> Uri.t
(** Return the resolver of page, that take relative URIs to absolute ones using
   the page base URI *)
val resolver : t -> Uri.t -> Uri.t

(** Convert to Lambdasoup *)
val soup : t -> Soup.soup Soup.node

(** {2 Lazy sequences}
    Lambda soup provides lazy sequences to traverse only needed part of an HTML
    document when used in combination with [with_stop]. We provide a wrapper
    that is compatible with Mechaml types such as forms, images, inputs, etc. *)

(** Lazy sequences of HTML elements. See [Soup.nodes] type *)
type +'a seq

(** [Soup.stop] type *)
type 'a stop = 'a Soup.stop = { throw : 'b. 'a -> 'b }

(** Operations on lazy sequences *)

val iter : ('a -> unit) -> 'a seq -> unit
val fold : ('a -> 'b -> 'a) -> 'a -> 'b seq -> 'a
val filter : ('a -> bool) -> 'a seq -> 'a seq

val first : 'a seq -> 'a option
val nth : int -> 'a seq -> 'a option
val find_first : ('a -> bool) -> 'a seq -> 'a option

val to_list : 'a seq -> 'a list

(** see Lambdasoup's [Soup.with_stop] *)
val with_stop : ('a stop -> 'a) -> 'a

(** {3 Form} *)

(** Operations on forms and inputs *)
module Form : sig
  type t

  (** Phantom types for inputs *)

  type checkbox
  type radio_button
  type select_list
  type menu
  type field
  type file_upload

  (** A form input *)
  type _ input

  (** Return the name of the form *)
  val name : t -> string option

  (** Return the action attribute of the form *)
  val action : t -> Uri.t

  (** Return the absolute (resolved) uri corresponding to the action attribute *)
  val uri : t -> Uri.t

  (** Return the method attribute of the form (`GET by default)*)
  val meth : t -> [`POST | `GET]

  (** Convert a form to a Soup node *)
  val to_node : t -> Soup.element Soup.node

  (** Convert an input to a Soup node *)
  val input_to_node : _ input -> Soup.element Soup.node

  (** Set directly the value(s) of a field *)

  val set : string -> string -> t -> t
  val set_multi : string -> string list -> t -> t

  (** Get the value(s) of a field *)

  val get : string -> t -> string option
  val get_multi : string -> t -> string list

  (** Reset the value of a field to its default (or remove it if there is no
     default
     value) *)
  val reset : string -> t -> t

  (** Remove the value of a field *)
  val clear : string -> t -> t

  (** Return all set values as a list *)
  val values : t -> (string * string list) list

  (** Return the name of an input *)
  val iname : (_ input) -> string option

  (** All the following function are built using the same pattern.

      - xxxs (eg {!checkboxes}) return all the inputs of a certain type as a lazy
      sequence.
      For example, [checkboxes myform] will return all the checkboxes of the form
      - xxx_with take a CSS selector as parameter, and return the first input that
      matches the selector, or [None] if there isn't any. Eg, [fields_with myform
      "\[name$=text2\]"] will try to find any text field which name ends with
      [text2]
      - xxxs_with proceed as the previous one, but return a lazy sequence of all inputs matching the
      selector.

  *)

  val checkbox_with : string -> t -> checkbox input option
  val checkboxes : t -> checkbox input seq
  val checkboxes_with : string -> t -> checkbox input seq

  val radio_button_with : string -> t -> radio_button input option
  val radio_buttons : t -> radio_button input seq
  val radio_buttons_with : string -> t -> radio_button input seq

  val select_list_with : string -> t -> select_list input option
  val select_lists : t -> select_list input seq
  val select_lists_with : string -> t -> select_list input seq

  val field_with : string -> t -> field input option
  val fields : t -> field input seq
  val fields_with : string -> t -> field input seq

  val text_with : string -> t -> field input option
  val texts : t -> field input seq
  val texts_with : string -> t -> field input seq

  val password_with : string -> t -> field input option
  val passwords : t -> field input seq
  val passwords_with : string -> t -> field input seq

  val hidden_with : string -> t -> field input option
  val hiddens : t -> field input seq
  val hiddens_with : string -> t -> field input seq

  val int_with : string -> t -> field input option
  val ints : t -> field input seq
  val ints_with : string -> t -> field input seq

  val textarea_with : string -> t -> field input option
  val textareas : t -> field input seq
  val textareas_with : string -> t -> field input seq

  val keygen_with : string -> t -> field input option
  val keygens : t -> field input seq
  val keygens_with : string -> t -> field input seq

  val file_upload_with : string -> t -> file_upload input option
  val file_uploads : t -> file_upload input seq
  val file_uploads_with : string -> t -> file_upload input seq

  (** Reset or clear all the fields *)

  val reset_all : t -> t
  val clear_all : t -> t

  (** Operation on Checkboxes *)
  module Checkbox : sig
    (** Return the value (the label) of a checkbox *)
    val value : checkbox input -> string

    (** Return the values of all the checkboxes with the same name asthe
       given one *)
    val values : t -> checkbox input -> string list

    (** Return all the checkboxes with the same name as the given one *)
    val choices : t -> checkbox input -> checkbox input seq

    (** Return the list of all checked checkboxes with the same name as the
       given one *)
    val checked : t -> checkbox input -> string list

    val check : t -> checkbox input -> t
    val uncheck : t -> checkbox input -> t
    val is_checked : t -> checkbox input -> bool
  end

  (** Operations on Radio Buttons *)
  module RadioButton : sig

    (** Similar to checkboxes, except that selecting one radio button in group
       automatically unselect the others *)

    val value : radio_button input -> string
    val values : t -> radio_button input -> string list
    val choices : t -> radio_button input -> radio_button input seq

    (** Return the possibly selected radio button *)
    val selected : t -> checkbox input -> string option

    val select : t -> radio_button input -> t
    val is_selected : t -> radio_button input -> bool
  end

  (** Operations on Menu (select lists) *)
  module SelectList : sig
    (** Represent an item of the list *)
    type item

    (** Return a list of all items of a given list *)
    val items : select_list input -> item list

    val selected : t -> select_list input -> string option
    val select : t -> select_list input -> item -> t
    val unselect : t -> select_list input -> item -> t
    val is_selected : t -> select_list input -> item -> bool

    (** Label of an item *)
    val to_string : item -> string
  end

  (** Operations on text fields : textarea, text/password type input, etc. *)
  module Field : sig
    val set : t -> field input -> string -> t
    val get : t -> field input -> string option
  end

  (** Operation on file upload fields *)
  module FileUpload : sig
    val select : t -> file_upload input -> string -> t
    val which_selected : t -> file_upload input -> string option
  end
end

(** {4 Images and links} *)

(** Operations on hypertext links *)
module Link : sig
  type t

  val href : t -> string
  val text : t -> string option
  val uri : t -> Uri.t

  val make : ?resolver:(Uri.t -> Uri.t) -> ?text:string -> href:string -> t

  val to_node : t -> Soup.element Soup.node
end

(** Operations on images *)
module Image : sig
  type t

  val source : t -> string
  val uri : t -> Uri.t

  val make : ?resolver:(Uri.t -> Uri.t) -> source:string -> t

  val to_node : t -> Soup.element Soup.node
end

(** {5 Nodes selection} *)

(** All the following function are built using the same pattern.

    - xxxs (eg {!forms}) return all the elements of a certain type as a lazy
    sequence.
    For example, [forms mypage] will return all the forms in the page
    - xxx_with take a CSS selector as parameter, and return the first element that
    matches the selector, or [None] if there isn't any. Eg, [link_with
    "\[href$=.jpg\]" mypage] will try to find a link that point to a JPEG image
    - xxxs_with proceed as the previous one, but return a lazy sequence of all elements matching the
    selector.
*)

val form_with : string -> t -> Form.t option
val forms_with : string -> t -> Form.t seq
val forms : t -> Form.t seq

val link_with : string -> t -> Link.t option
val links_with : string -> t -> Link.t seq
val links : t -> Link.t seq

val image_with : string -> t -> Image.t option
val images_with : string -> t -> Image.t seq
val images : t -> Image.t seq
