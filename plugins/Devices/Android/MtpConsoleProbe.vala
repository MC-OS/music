// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Dump the internal storage of whatever device is connected (storage id from the device, not hardcoded). */

public class Music.Plugins.MtpConsoleProbe : GLib.Object {
    private static bool lib_ready = false;
    private bool probing = false;

    public MtpConsoleProbe () {
        if (!lib_ready) {
            Mtp.init ();
            Mtp.set_debug (0);
            lib_ready = true;
        }
    }

    public void probe_now (string reason) {
        if (probing) {
            return;
        }

        probing = true;
        print ("\n========== MTP native probe (%s) ==========\n", reason);

        release_gvfs_mtp_async.begin ((obj, res) => {
            release_gvfs_mtp_async.end (res);
            Timeout.add (500, () => {
                open_and_dump ();
                probing = false;
                return false;
            });
        });
    }

    private async void release_gvfs_mtp_async () {
        var vm = VolumeMonitor.get ();
        foreach (var mount in vm.get_mounts ()) {
            var root = mount.get_default_location ();
            if (root == null) {
                continue;
            }
            var uri = root.get_uri () ?? "";
            if (!uri.has_prefix ("mtp://") && !uri.has_prefix ("gphoto2://")) {
                continue;
            }
            try {
                yield mount.unmount_with_operation (MountUnmountFlags.NONE, null, null);
            } catch (Error e) {
                print ("[MTP probe] Unmount failed: %s\n", e.message);
            }
        }
    }

    /* Pick the internal storage from the connected device's own list.
       Skip SD card / external / removable; fall back to the first storage. */
    private unowned Mtp.Storage? pick_internal_storage (unowned Mtp.Device device) {
        if (device.get_storage (0) != 0 || device.storage == null) {
            return null;
        }
        unowned Mtp.Storage? best = null;
        unowned Mtp.Storage? store = device.storage;
        while (store != null) {
            var desc = (store.StorageDescription ?? "").down ();
            bool external = desc.contains ("sd")
                || desc.contains ("card")
                || desc.contains ("external")
                || desc.contains ("removable");
            if (!external) {
                if (best == null || store.MaxCapacity > best.MaxCapacity) {
                    best = store;
                }
            }
            store = store.next;
        }
        return best ?? device.storage;
    }

    private void dump_folder (unowned Mtp.Device device, uint32 storage_id, uint32 parent_id, int depth) {
        unowned Mtp.File? file = device.get_files_and_folders (storage_id, parent_id);
        if (file == null) {
            return;
        }

        while (file != null) {
            var indent = string.nfill (depth * 2, ' ');
            var kind = file.filetype == Mtp.Filetype.FOLDER ? "[dir] " : "      ";
            var size = file.filetype == Mtp.Filetype.FOLDER ? "" : " (%s)".printf (format_size (file.filesize));
            print ("%s%s%s%s\n", indent, kind, file.filename ?? "(unnamed)", size);

            if (file.filetype == Mtp.Filetype.FOLDER) {
                dump_folder (device, storage_id, file.item_id, depth + 1);
            }

            unowned Mtp.File? next = file.next;
            Mtp.destroy_file_t (file);
            file = next;
        }
    }

    private void open_and_dump () {
        unowned Mtp.Device? device = Mtp.get_first_device ();
        if (device == null) {
            print ("[MTP probe] No device\n");
            print ("========== end probe ==========\n\n");
            return;
        }

        print ("  Friendly name : %s\n", device.get_friendly_name () ?? "(empty)");
        print ("  Manufacturer  : %s\n", device.get_manufacturer_name () ?? "(null)");
        print ("  Model         : %s\n", device.get_model_name () ?? "(null)");
        print ("  Serial        : %s\n", device.get_serial_number () ?? "(null)");
        print ("  Device ver.   : %s\n", device.get_device_version () ?? "(null)");

        uint8 max_level = 0, cur_level = 0;
        if (device.get_battery_level (out max_level, out cur_level) == 0 && max_level > 0) {
            print ("  Battery       : %u / %u (%u%%)\n", cur_level, max_level, (cur_level * 100) / max_level);
        } else {
            print ("  Battery       : (unavailable)\n");
        }

        unowned Mtp.Storage? store = pick_internal_storage (device);
        if (store == null) {
            print ("  Storage       : (none reported)\n");
        } else {
            print ("  Internal storage (id 0x%08x): %s\n", store.id, store.StorageDescription ?? "(unnamed)");
            print ("    capacity    : %s\n", format_size (store.MaxCapacity));
            print ("    free        : %s\n", format_size (store.FreeSpaceInBytes));
            print ("  --- files & folders ---\n");
            dump_folder (device, store.id, Mtp.FILES_AND_FOLDERS_ROOT, 0);
        }

        Mtp.release_device (device);
        print ("========== end probe ==========\n\n");
    }
}
