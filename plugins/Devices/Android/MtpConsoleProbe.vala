// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Native MTP probe: try to free the device from GVFS, open with libmtp,
 * print every useful field to the terminal (stdout). No UI.
 */

namespace Music.Plugins {

public class MtpConsoleProbe : GLib.Object {
    private static bool lib_ready = false;
    private bool probing = false;

    public MtpConsoleProbe () {
        if (!lib_ready) {
            Mtp.init ();
            /* 0 = off; raise if you need libmtp's own noise */
            Mtp.set_debug (0);
            lib_ready = true;
        }
    }

    /** Best-effort: unmount MTP so libmtp can claim USB. */
    public void release_gvfs_mtp () {
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

            print ("[MTP probe] Unmounting GVFS: %s\n", uri);
            try {
                mount.unmount_with_operation (MountUnmountFlags.NONE, null, null);
            } catch (Error e) {
                print ("[MTP probe] Unmount failed: %s\n", e.message);
            }
        }
    }

    public void probe_now (string reason) {
        if (probing) {
            return;
        }

        probing = true;
        print ("\n========== MTP native probe (%s) ==========\n", reason);

        release_gvfs_mtp ();

        /* Give GVFS a moment to drop the interface */
        Timeout.add (400, () => {
            open_and_dump ();
            probing = false;
            return false;
        });
    }

    private void open_and_dump () {
        var device = Mtp.get_first_device ();
        if (device == null) {
            print ("[MTP probe] LIBMTP_Get_First_Device returned NULL.\n");
            print ("[MTP probe] Usual cause: GVFS/KIO still owns USB, or phone not in file-transfer mode.\n");
            print ("========== end probe ==========\n\n");
            return;
        }

        print ("[MTP probe] Device session opened.\n");

        print ("  Friendly name : %s\n", device.get_friendly_name () ?? "(null)");
        print ("  Manufacturer  : %s\n", device.get_manufacturer_name () ?? "(null)");
        print ("  Model         : %s\n", device.get_model_name () ?? "(null)");
        print ("  Serial        : %s\n", device.get_serial_number () ?? "(null)");
        print ("  Device version: %s\n", device.get_device_version () ?? "(null)");

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
            device.dump_errorstack ();
            device.clear_errorstack ();
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
            device.dump_errorstack ();
            device.clear_errorstack ();
        }

        print ("--- libmtp Dump_Device_Info ---\n");
        device.dump_device_info ();
        print ("--- end Dump_Device_Info ---\n");

        Mtp.release_device (device);
        print ("[MTP probe] Session released.\n");
        print ("========== end probe ==========\n\n");
    }

    private static string format_size (uint64 bytes) {
        return GLib.format_size (bytes);
    }
}

}
