(* Example showing how to create a disk image. *)

open Unix
open Printf

let output = "disk.img"

let () =
  let g = new Guestfs.guestfs () in

  (* Create a raw-format sparse disk image, 512 MB in size. *)
  let fd = openfile output [O_WRONLY;O_CREAT;O_TRUNC;O_NOCTTY] 0o666 in
  ftruncate fd (512 * 1024 * 1024);
  close fd;

  (* Set the trace flag so that we can see each libguestfs call. *)
  g#set_trace true;

  (* Set the autosync flag so that the disk will be synchronized
   * automatically when the libguestfs handle is closed.
   *)
  g#set_autosync true;

  (* Attach the disk image to libguestfs. *)
  g#add_drive_opts ~format:"raw" ~readonly:false output;

  (* Run the libguestfs back-end. *)
  g#launch ();

  (* Get the list of devices.  Because we only added one drive
   * above, we expect that this list should contain a single
   * element.
   *)
  let devices = g#list_devices () in
  if Array.length devices <> 1 then
    failwith "error: expected a single device from list-devices";

  (* Partition the disk as one single MBR partition. *)
  g#part_disk devices.(0) "mbr";

  (* Get the list of partitions.  We expect a single element, which
   * is the partition we have just created.
   *)
  let partitions = g#list_partitions () in
  if Array.length partitions <> 1 then
    failwith "error: expected a single partition from list-partitions";

  (* Create a filesystem on the partition. *)
  g#mkfs "ext4" partitions.(0);

  (* Now mount the filesystem so that we can add files. *)
  g#mount_options "" partitions.(0) "/";

  (* Create some files and directories. *)
  g#touch "/empty";
  let message = "Hello, world\n" in
  g#write "/hello" message;
  g#mkdir "/foo";

  (* This one uploads the local file /etc/resolv.conf into
   * the disk image.
   *)
  g#upload "/etc/resolv.conf" "/foo/resolv.conf";

  (* Because 'autosync' was set (above) we can just close the handle
   * and the disk contents will be synchronized.  You can also do
   * this manually by calling g#umount_all and g#sync.
   *
   * Note also that handles are automatically closed if they are
   * reaped by the garbage collector.  You only need to call close
   * if you want to close the handle right away.
   *)
  g#close ()
