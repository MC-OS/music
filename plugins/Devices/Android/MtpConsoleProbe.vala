// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Optional console dump helper (not started by default plugin path). */

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

        Mtp.release_device (device);
        print ("========== end probe ==========\n\n");
    }
}
