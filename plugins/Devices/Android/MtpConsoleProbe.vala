// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Full MTP device dump: GetDeviceInfo fields, storage, capability list.
 * Uses message(). */

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
        message ("\n========== MTP native probe (%s) ==========", reason);

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
                message ("[MTP probe] Unmount failed: %s", e.message);
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
            message ("%s%s%s%s", indent, kind, file.filename ?? "(unnamed)", size);

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
            message ("[MTP probe] No device");
            message ("========== end probe ==========\n");
            return;
        }

        /* Full capability dump: operations, events, device props, object formats.
         * This writes to stdout (not message()), so look at the terminal. */
        message ("--- LIBMTP_Dump_Device_Info (stdout) ---");
        device.dump_device_info ();

        /* GetDeviceInfo fields (manufacturer, model, version, serial, extensions). */
        message ("--- GetDeviceInfo ---");
        message ("  Manufacturer  : %s", device.get_manufacturer_name () ?? "(null)");
        message ("  Model         : %s", device.get_model_name () ?? "(null)");
        message ("  Device ver.   : %s", device.get_device_version () ?? "(null)");
        message ("  Serial        : %s", device.get_serial_number () ?? "(null)");
        message ("  Friendly name : %s", device.get_friendly_name () ?? "(empty)");

        /* Storage: capacity, free space, description. */
        message ("--- Storage ---");
        unowned Mtp.Storage? store = pick_internal_storage (device);
        if (store == null) {
            message ("  (none reported)");
        } else {
            message ("  Internal storage (id 0x%08x): %s", store.id, store.StorageDescription ?? "(unnamed)");
            message ("    capacity    : %s", format_size (store.MaxCapacity));
            message ("    free        : %s", format_size (store.FreeSpaceInBytes));
            message ("    free objs   : %llu", store.FreeSpaceInObjects);
            message ("    volume id   : %s", store.VolumeIdentifier ?? "(none)");
        }

        /* Battery. */
        uint8 max_level = 0, cur_level = 0;
        if (device.get_battery_level (out max_level, out cur_level) == 0 && max_level > 0) {
            message ("  Battery       : %u / %u (%u%%)", cur_level, max_level, (cur_level * 100) / max_level);
        } else {
            message ("  Battery       : (unavailable)");
        }

        /* Sync partner. */
        string? sync = device.get_syncpartner ();
        message ("  Sync partner  : %s", sync ?? "(empty)");

        /* Folder tree. */
        if (store != null) {
            message ("--- files & folders ---");
            dump_folder (device, store.id, Mtp.FILES_AND_FOLDERS_ROOT, 0);
        }

        Mtp.release_device (device);
        message ("========== end probe ==========\n");
    }
}
