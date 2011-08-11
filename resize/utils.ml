(* virt-resize
 * Copyright (C) 2010-2011 Red Hat Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *)

open Printf

module G = Guestfs

let ( +^ ) = Int64.add
let ( -^ ) = Int64.sub
let ( *^ ) = Int64.mul
let ( /^ ) = Int64.div
let ( &^ ) = Int64.logand
let ( ~^ ) = Int64.lognot

let output_spaces chan n = for i = 0 to n-1 do output_char chan ' ' done

let wrap ?(chan = stdout) ?(hanging = 0) str =
  let rec _wrap col str =
    let n = String.length str in
    let i = try String.index str ' ' with Not_found -> n in
    let col =
      if col+i >= 72 then (
        output_char chan '\n';
        output_spaces chan hanging;
        i+hanging+1
      ) else col+i+1 in
    output_string chan (String.sub str 0 i);
    if i < n then (
      output_char chan ' ';
      _wrap col (String.sub str (i+1) (n-(i+1)))
    )
  in
  _wrap 0 str

let error fs =
  let display str =
    wrap ~chan:stderr ("virt-resize: error: " ^ str);
    prerr_newline ();
    prerr_newline ();
    wrap ~chan:stderr
      "If reporting bugs, run virt-resize with the '-d' option and include the complete output.";
    prerr_newline ();
    exit 1
  in
  ksprintf display fs

(* The reverse of device name translation, see
 * BLOCK DEVICE NAMING in guestfs(3).
 *)
let canonicalize dev =
  if String.length dev >= 8 &&
    dev.[0] = '/' && dev.[1] = 'd' && dev.[2] = 'e' && dev.[3] = 'v' &&
    dev.[4] = '/' && (dev.[5] = 'h' || dev.[5] = 'v') && dev.[6] = 'd' then (
      let dev = String.copy dev in
      dev.[5] <- 's';
      dev
    )
  else
    dev

let feature_available (g : Guestfs.guestfs) names =
  try g#available names; true
  with G.Error _ -> false

(* Parse the size field from --resize and --resize-force options. *)
let parse_size =
  let const_re = Pcre.regexp "^([.\\d]+)([bKMG])$"
  and plus_const_re = Pcre.regexp "^\\+([.\\d]+)([bKMG])$"
  and minus_const_re = Pcre.regexp "^-([.\\d]+)([bKMG])$"
  and percent_re = Pcre.regexp "^([.\\d]+)%$"
  and plus_percent_re = Pcre.regexp "^\\+([.\\d]+)%$"
  and minus_percent_re = Pcre.regexp "^-([.\\d]+)%$"
  in
  fun oldsize field ->
    let subs = ref None in
    let matches rex =
      try subs := Some (Pcre.exec ~rex field); true
      with Not_found -> false
    in
    let sub i =
      match !subs with None -> assert false
      | Some subs -> Pcre.get_substring subs i
    in
    let size_scaled f = function
      | "b" -> Int64.of_float f
      | "K" -> Int64.of_float (f *. 1024.)
      | "M" -> Int64.of_float (f *. 1024. *. 1024.)
      | "G" -> Int64.of_float (f *. 1024. *. 1024. *. 1024.)
      | _ -> assert false
    in

    if matches const_re then (
      size_scaled (float_of_string (sub 1)) (sub 2)
    )
    else if matches plus_const_re then (
      let incr = size_scaled (float_of_string (sub 1)) (sub 2) in
      oldsize +^ incr
    )
    else if matches minus_const_re then (
      let incr = size_scaled (float_of_string (sub 1)) (sub 2) in
      oldsize -^ incr
    )
    else if matches percent_re then (
      let percent = Int64.of_float (10. *. float_of_string (sub 1)) in
      oldsize *^ percent /^ 1000L
    )
    else if matches plus_percent_re then (
      let percent = Int64.of_float (10. *. float_of_string (sub 1)) in
      oldsize +^ oldsize *^ percent /^ 1000L
    )
    else if matches minus_percent_re then (
      let percent = Int64.of_float (10. *. float_of_string (sub 1)) in
      oldsize -^ oldsize *^ percent /^ 1000L
    )
    else
      error "virt-resize: %s: cannot parse size field" field

let human_size i =
  let sign, i = if i < 0L then "-", Int64.neg i else "", i in

  if i < 1024L then
    sprintf "%s%Ld" sign i
  else (
    let f = Int64.to_float i /. 1024. in
    let i = i /^ 1024L in
    if i < 1024L then
      sprintf "%s%.1fK" sign f
    else (
      let f = Int64.to_float i /. 1024. in
      let i = i /^ 1024L in
      if i < 1024L then
        sprintf "%s%.1fM" sign f
      else (
        let f = Int64.to_float i /. 1024. in
        (*let i = i /^ 1024L in*)
        sprintf "%s%.1fG" sign f
      )
    )
  )