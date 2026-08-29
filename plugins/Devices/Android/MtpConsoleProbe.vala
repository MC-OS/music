// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Native MTP probe: try to free the device from GVFS, open with libmtp,
 * print identity/storage/battery to the terminal (stdout). No UI.
 */

namespace Music.Plugins {

public class MtpConsoleProbe : GLib.Object {
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
        var mounts = vm.get_mounts ();

        foreach (var mount in mounts) {
            var root = mount.get_default_location ();
            if (root == null) {
                continue;
            }

            var uri = root.get_uri () ?? "";
            if (!uri.has_prefix ("mtp://") && !uri.has_prefix ("gphoto2://")) {
                continue;
            }

            print ("[MTP probe] Unmounting GVFS: %s\n", uri);
            try {
                yield mount.unmount_with_operation (MountUnmountFlags.NONE, null, null);
                print ("[MTP probe] Unmounted OK\n");
            } catch (Error e) {
                print ("[MTP probe] Unmount failed: %s\n", e.message);
            }
        }
    }

    private void open_and_dump () {
        Mtp.Device? device = Mtp.get_first_device ();
        if (device == null) {
            print ("[MTP probe] LIBMTP_Get_First_Device returned NULL.\n");
            print ("[MTP probe] Usual cause: GVFS/KIO still owns USB, or phone not in file-transfer mode.\n");
            print ("========== end probe ==========\n\n");
            return;
        }

        print ("[MTP probe] Device session opened.\n");

        unowned string? friendly = device.get_friendly_name ();
        unowned string? mfr = device.get_manufacturer_name ();
        unowned string? model = device.get_model_name ();
        unowned string? serial = device.get_serial_number ();
        unowned string? version = device.get_device_version ();

        print ("  Friendly name : %s\n", (friendly != null && friendly.length > 0) ? friendly : "(empty)");
        print ("  Manufacturer  : %s\n", mfr ?? "(null)");
        print ("  Model         : %s\n", model ?? "(null)");
        print ("  Serial        : %s\n", serial ?? "(null)");
        print ("  Device version: %s\n", version ?? "(null)");

        uint8 max_level = 0;
        uint8 cur_level = 0;
        if (device.get_battery_level (out max_level, out cur_level) == 0) {
            int pct = (max_level > 0) ? (int) ((cur_level * 100) / max_level) : -1;
            print ("  Battery       : %u / %u", cur_level, max_level);
            if (pct >= 0) {
                print (" (%d%%)", pct);
            }
            print ("\n");
        } else {
            print ("  Battery       : (unsupported or error)\n");
        }

        if (device.get_storage (0) == 0 && device.storage != null) {
            int i = 0;
            unowned Mtp.Storage? store = device.storage;
            while (store != null) {
                print ("  Storage[%d]\n", i);
                print ("    id          : %u\n", store.id);
                print ("    description : %s\n", store.StorageDescription ?? "(null)");
                print ("    volume id   : %s\n", store.VolumeIdentifier ?? "(null)");
                print ("    max capacity: %s (%llu bytes)\n",
                    format_size (store.MaxCapacity), store.MaxCapacity);
                print ("    free space  : %s (%llu bytes)\n",
                    format_size (store.FreeSpaceInBytes), store.FreeSpaceInBytes);
                store = store.next;
                i++;
            }
        } else {
            print ("  Storage       : (none / get_storage failed)\n");
        }

        Mtp.release_device (device);
        device = null;
        print ("[MTP probe] Session released.\n");
        print ("========== end probe ==========\n\n");
    }

    private static string format_size (uint64 bytes) {
        return GLib.format_size (bytes);
    }
}

} // namespace Music.Plugins
