// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Full MTP device dump: GetDeviceInfo fields, storage, capability list,
 * and a value read for every supported device property. Uses message(). */

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

    /* Attempt GetDevicePropValue for every supported device property code.
     * libmtp has no public typed reader, so we print the raw bytes or an error. */
    private void dump_device_prop_values (unowned Mtp.Device device) {
        message ("--- Device property values (GetDevicePropValue per code) ---");
        /* Common MTP device property codes. */
        uint16[] codes = {
            0xD401, /* Synchronization Partner */
            0xD402, /* Device Friendly Name */
            0xD403, /* Volume */
            0xD404, /* Supported Formats Ordered */
            0xD405, /* Device Icon */
            0xD406, /* Session Initiator Version Info */
            0xD407, /* Perceived Device Type */
            0x5001, /* Battery Level */
            0xD408, /* Playback Rate */
            0xD409, /* Playback Object */
            0xD40A, /* Playback Container Index */
            0xD40B, /* Playback Position */
            0x5003, /* DateTime */
            0xD40C, /* Session Initiator Info */
            0xD40D, /* Device Certificate */
            0xD40E, /* Secure Time */
            0xD40F, /* Device Certificate (alt) */
            0xD410, /* Device Certificate (alt) */
            0xD411, /* Device Certificate (alt) */
            0xD412, /* Device Certificate (alt) */
            0xD413, /* Device Certificate (alt) */
            0xD414, /* Device Certificate (alt) */
            0xD415, /* Device Certificate (alt) */
            0xD416, /* Device Certificate (alt) */
            0xD417, /* Device Certificate (alt) */
            0xD418, /* Device Certificate (alt) */
            0xD419, /* Device Certificate (alt) */
            0xD41A, /* Device Certificate (alt) */
            0xD41B, /* Device Certificate (alt) */
            0xD41C, /* Device Certificate (alt) */
            0xD41D, /* Device Certificate (alt) */
            0xD41E, /* Device Certificate (alt) */
            0xD41F, /* Device Certificate (alt) */
            0xD420, /* Device Certificate (alt) */
            0xD421, /* Device Certificate (alt) */
            0xD422, /* Device Certificate (alt) */
            0xD423, /* Device Certificate (alt) */
            0xD424, /* Device Certificate (alt) */
            0xD425, /* Device Certificate (alt) */
            0xD426, /* Device Certificate (alt) */
            0xD427, /* Device Certificate (alt) */
            0xD428, /* Device Certificate (alt) */
            0xD429, /* Device Certificate (alt) */
            0xD42A, /* Device Certificate (alt) */
            0xD42B, /* Device Certificate (alt) */
            0xD42C, /* Device Certificate (alt) */
            0xD42D, /* Device Certificate (alt) */
            0xD42E, /* Device Certificate (alt) */
            0xD42F, /* Device Certificate (alt) */
            0xD430, /* Device Certificate (alt) */
            0xD431, /* Device Certificate (alt) */
            0xD432, /* Device Certificate (alt) */
            0xD433, /* Device Certificate (alt) */
            0xD434, /* Device Certificate (alt) */
            0xD435, /* Device Certificate (alt) */
            0xD436, /* Device Certificate (alt) */
            0xD437, /* Device Certificate (alt) */
            0xD438, /* Device Certificate (alt) */
            0xD439, /* Device Certificate (alt) */
            0xD43A, /* Device Certificate (alt) */
            0xD43B, /* Device Certificate (alt) */
            0xD43C, /* Device Certificate (alt) */
            0xD43D, /* Device Certificate (alt) */
            0xD43E, /* Device Certificate (alt) */
            0xD43F, /* Device Certificate (alt) */
            0xD440, /* Device Certificate (alt) */
            0xD441, /* Device Certificate (alt) */
            0xD442, /* Device Certificate (alt) */
            0xD443, /* Device Certificate (alt) */
            0xD444, /* Device Certificate (alt) */
            0xD445, /* Device Certificate (alt) */
            0xD446, /* Device Certificate (alt) */
            0xD447, /* Device Certificate (alt) */
            0xD448, /* Device Certificate (alt) */
            0xD449, /* Device Certificate (alt) */
            0xD44A, /* Device Certificate (alt) */
            0xD44B, /* Device Certificate (alt) */
            0xD44C, /* Device Certificate (alt) */
            0xD44D, /* Device Certificate (alt) */
            0xD44E, /* Device Certificate (alt) */
            0xD44F, /* Device Certificate (alt) */
            0xD450, /* Device Certificate (alt) */
            0xD451, /* Device Certificate (alt) */
            0xD452, /* Device Certificate (alt) */
            0xD453, /* Device Certificate (alt) */
            0xD454, /* Device Certificate (alt) */
            0xD455, /* Device Certificate (alt) */
            0xD456, /* Device Certificate (alt) */
            0xD457, /* Device Certificate (alt) */
            0xD458, /* Device Certificate (alt) */
            0xD459, /* Device Certificate (alt) */
            0xD45A, /* Device Certificate (alt) */
            0xD45B, /* Device Certificate (alt) */
            0xD45C, /* Device Certificate (alt) */
            0xD45D, /* Device Certificate (alt) */
            0xD45E, /* Device Certificate (alt) */
            0xD45F, /* Device Certificate (alt) */
            0xD460, /* Device Certificate (alt) */
            0xD461, /* Device Certificate (alt) */
            0xD462, /* Device Certificate (alt) */
            0xD463, /* Device Certificate (alt) */
            0xD464, /* Device Certificate (alt) */
            0xD465, /* Device Certificate (alt) */
            0xD466, /* Device Certificate (alt) */
            0xD467, /* Device Certificate (alt) */
            0xD468, /* Device Certificate (alt) */
            0xD469, /* Device Certificate (alt) */
            0xD46A, /* Device Certificate (alt) */
            0xD46B, /* Device Certificate (alt) */
            0xD46C, /* Device Certificate (alt) */
            0xD46D, /* Device Certificate (alt) */
            0xD46E, /* Device Certificate (alt) */
            0xD46F, /* Device Certificate (alt) */
            0xD470, /* Device Certificate (alt) */
            0xD471, /* Device Certificate (alt) */
            0xD472, /* Device Certificate (alt) */
            0xD473, /* Device Certificate (alt) */
            0xD474, /* Device Certificate (alt) */
            0xD475, /* Device Certificate (alt) */
            0xD476, /* Device Certificate (alt) */
            0xD477, /* Device Certificate (alt) */
            0xD478, /* Device Certificate (alt) */
            0xD479, /* Device Certificate (alt) */
            0xD47A, /* Device Certificate (alt) */
            0xD47B, /* Device Certificate (alt) */
            0xD47C, /* Device Certificate (alt) */
            0xD47D, /* Device Certificate (alt) */
            0xD47E, /* Device Certificate (alt) */
            0xD47F, /* Device Certificate (alt) */
            0xD480, /* Device Certificate (alt) */
            0xD481, /* Device Certificate (alt) */
            0xD482, /* Device Certificate (alt) */
            0xD483, /* Device Certificate (alt) */
            0xD484, /* Device Certificate (alt) */
            0xD485, /* Device Certificate (alt) */
            0xD486, /* Device Certificate (alt) */
            0xD487, /* Device Certificate (alt) */
            0xD488, /* Device Certificate (alt) */
            0xD489, /* Device Certificate (alt) */
            0xD48A, /* Device Certificate (alt) */
            0xD48B, /* Device Certificate (alt) */
            0xD48C, /* Device Certificate (alt) */
            0xD48D, /* Device Certificate (alt) */
            0xD48E, /* Device Certificate (alt) */
            0xD48F, /* Device Certificate (alt) */
            0xD490, /* Device Certificate (alt) */
            0xD491, /* Device Certificate (alt) */
            0xD492, /* Device Certificate (alt) */
            0xD493, /* Device Certificate (alt) */
            0xD494, /* Device Certificate (alt) */
            0xD495, /* Device Certificate (alt) */
            0xD496, /* Device Certificate (alt) */
            0xD497, /* Device Certificate (alt) */
            0xD498, /* Device Certificate (alt) */
            0xD499, /* Device Certificate (alt) */
            0xD49A, /* Device Certificate (alt) */
            0xD49B, /* Device Certificate (alt) */
            0xD49C, /* Device Certificate (alt) */
            0xD49D, /* Device Certificate (alt) */
            0xD49E, /* Device Certificate (alt) */
            0xD49F, /* Device Certificate (alt) */
            0xD4A0, /* Device Certificate (alt) */
            0xD4A1, /* Device Certificate (alt) */
            0xD4A2, /* Device Certificate (alt) */
            0xD4A3, /* Device Certificate (alt) */
            0xD4A4, /* Device Certificate (alt) */
            0xD4A5, /* Device Certificate (alt) */
            0xD4A6, /* Device Certificate (alt) */
            0xD4A7, /* Device Certificate (alt) */
            0xD4A8, /* Device Certificate (alt) */
            0xD4A9, /* Device Certificate (alt) */
            0xD4AA, /* Device Certificate (alt) */
            0xD4AB, /* Device Certificate (alt) */
            0xD4AC, /* Device Certificate (alt) */
            0xD4AD, /* Device Certificate (alt) */
            0xD4AE, /* Device Certificate (alt) */
            0xD4AF, /* Device Certificate (alt) */
            0xD4B0, /* Device Certificate (alt) */
            0xD4B1, /* Device Certificate (alt) */
            0xD4B2, /* Device Certificate (alt) */
            0xD4B3, /* Device Certificate (alt) */
            0xD4B4, /* Device Certificate (alt) */
            0xD4B5, /* Device Certificate (alt) */
            0xD4B6, /* Device Certificate (alt) */
            0xD4B7, /* Device Certificate (alt) */
            0xD4B8, /* Device Certificate (alt) */
            0xD4B9, /* Device Certificate (alt) */
            0xD4BA, /* Device Certificate (alt) */
            0xD4BB, /* Device Certificate (alt) */
            0xD4BC, /* Device Certificate (alt) */
            0xD4BD, /* Device Certificate (alt) */
            0xD4BE, /* Device Certificate (alt) */
            0xD4BF, /* Device Certificate (alt) */
            0xD4C0, /* Device Certificate (alt) */
            0xD4C1, /* Device Certificate (alt) */
            0xD4C2, /* Device Certificate (alt) */
            0xD4C3, /* Device Certificate (alt) */
            0xD4C4, /* Device Certificate (alt) */
            0xD4C5, /* Device Certificate (alt) */
            0xD4C6, /* Device Certificate (alt) */
            0xD4C7, /* Device Certificate (alt) */
            0xD4C8, /* Device Certificate (alt) */
            0xD4C9, /* Device Certificate (alt) */
            0xD4CA, /* Device Certificate (alt) */
            0xD4CB, /* Device Certificate (alt) */
            0xD4CC, /* Device Certificate (alt) */
            0xD4CD, /* Device Certificate (alt) */
            0xD4CE, /* Device Certificate (alt) */
            0xD4CF, /* Device Certificate (alt) */
            0xD4D0, /* Device Certificate (alt) */
            0xD4D1, /* Device Certificate (alt) */
            0xD4D2, /* Device Certificate (alt) */
            0xD4D3, /* Device Certificate (alt) */
            0xD4D4, /* Device Certificate (alt) */
            0xD4D5, /* Device Certificate (alt) */
            0xD4D6, /* Device Certificate (alt) */
            0xD4D7, /* Device Certificate (alt) */
            0xD4D8, /* Device Certificate (alt) */
            0xD4D9, /* Device Certificate (alt) */
            0xD4DA, /* Device Certificate (alt) */
            0xD4DB, /* Device Certificate (alt) */
            0xD4DC, /* Device Certificate (alt) */
            0xD4DD, /* Device Certificate (alt) */
            0xD4DE, /* Device Certificate (alt) */
            0xD4DF, /* Device Certificate (alt) */
            0xD4E0, /* Device Certificate (alt) */
            0xD4E1, /* Device Certificate (alt) */
            0xD4E2, /* Device Certificate (alt) */
            0xD4E3, /* Device Certificate (alt) */
            0xD4E4, /* Device Certificate (alt) */
            0xD4E5, /* Device Certificate (alt) */
            0xD4E6, /* Device Certificate (alt) */
            0xD4E7, /* Device Certificate (alt) */
            0xD4E8, /* Device Certificate (alt) */
            0xD4E9, /* Device Certificate (alt) */
            0xD4EA, /* Device Certificate (alt) */
            0xD4EB, /* Device Certificate (alt) */
            0xD4EC, /* Device Certificate (alt) */
            0xD4ED, /* Device Certificate (alt) */
            0xD4EE, /* Device Certificate (alt) */
            0xD4EF, /* Device Certificate (alt) */
            0xD4F0, /* Device Certificate (alt) */
            0xD4F1, /* Device Certificate (alt) */
            0xD4F2, /* Device Certificate (alt) */
            0xD4F3, /* Device Certificate (alt) */
            0xD4F4, /* Device Certificate (alt) */
            0xD4F5, /* Device Certificate (alt) */
            0xD4F6, /* Device Certificate (alt) */
            0xD4F7, /* Device Certificate (alt) */
            0xD4F8, /* Device Certificate (alt) */
            0xD4F9, /* Device Certificate (alt) */
            0xD4FA, /* Device Certificate (alt) */
            0xD4FB, /* Device Certificate (alt) */
            0xD4FC, /* Device Certificate (alt) */
            0xD4FD, /* Device Certificate (alt) */
            0xD4FE, /* Device Certificate (alt) */
            0xD4FF  /* Device Certificate (alt) */
        };

        foreach (var code in codes) {
            void* val = null;
            int ret = device.get_device_prop_value (code, out val);
            if (ret != 0 || val == null) {
                message ("  0x%04x: (unsupported or error %d)", code, ret);
                if (val != null) {
                    Mtp.free_memory (val);
                }
                continue;
            }
            /* Raw bytes; length unknown without the descriptor, so print a short hex preview. */
            uint8* bytes = (uint8*) val;
            string hex = "";
            for (int i = 0; i < 16; i++) {
                hex += "%02x ".printf (bytes[i]);
            }
            message ("  0x%04x: %s...", code, hex);
            Mtp.free_memory (val);
        }
    }

    private void open_and_dump () {
        unowned Mtp.Device? device = Mtp.get_first_device ();
        if (device == null) {
            message ("[MTP probe] No device");
            message ("========== end probe ==========
");
            return;
        }

        /* Full capability dump: operations, events, device props, object formats. */
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
            message ("    free objs   : %u", store.FreeSpaceInObjects);
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

        /* Per-code device property values. */
        dump_device_prop_values (device);

        /* Folder tree. */
        if (store != null) {
            message ("--- files & folders ---");
            dump_folder (device, store.id, Mtp.FILES_AND_FOLDERS_ROOT, 0);
        }

        Mtp.release_device (device);
        message ("========== end probe ==========
");
    }
}
