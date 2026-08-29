// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Discover via libmtp (after releasing GVFS), register at most one AndroidDevice. */

public class Music.Plugins.AndroidDeviceManager : GLib.Object {
    private Gee.ArrayList<AndroidDevice> devices;
    private VolumeMonitor volume_monitor;
    private bool busy = false;
    private bool announced = false;
    private uint scan_id = 0;
    private string? pending_label = null;
    private static bool lib_ready = false;

    public AndroidDeviceManager () {
        devices = new Gee.ArrayList<AndroidDevice> ();

        if (!lib_ready) {
            Mtp.init ();
            Mtp.set_debug (0);
            lib_ready = true;
        }

        volume_monitor = VolumeMonitor.get ();
        volume_monitor.volume_added.connect (on_hint);
        volume_monitor.mount_added.connect (on_hint);

        schedule_scan ("startup");
    }

    private void on_hint () {
        if (devices.size > 0 || busy || announced) {
            return;
        }
        schedule_scan ("hotplug");
    }

    public void remove_all () {
        if (scan_id != 0) {
            Source.remove (scan_id);
            scan_id = 0;
        }

        var dm = DeviceManager.get_default ();
        foreach (var dev in devices) {
            dev.release_mtp ();
            dm.device_removed ((Music.Device) dev);
        }
        devices.clear ();
        announced = false;
        busy = false;
        pending_label = null;
    }

    private void schedule_scan (string reason) {
        if (devices.size > 0 || busy || announced) {
            return;
        }

        if (scan_id != 0) {
            Source.remove (scan_id);
        }

        var r = reason;
        scan_id = Timeout.add (700, () => {
            scan_id = 0;
            try_open_native (r);
            return false;
        });
    }

    private string? pick_label (Mount mount) {
        var name = mount.get_name ();
        if (name != null && name.strip ().length > 0) {
            return name.strip ();
        }
        var volume = mount.get_volume ();
        if (volume != null) {
            var vn = volume.get_name ();
            if (vn != null && vn.strip ().length > 0) {
                return vn.strip ();
            }
            var drive = volume.get_drive ();
            if (drive != null) {
                var dn = drive.get_name ();
                if (dn != null && dn.strip ().length > 0) {
                    return dn.strip ();
                }
            }
        }
        return null;
    }

    private async void release_gvfs_mtp () {
        pending_label = null;

        foreach (var mount in volume_monitor.get_mounts ()) {
            var root = mount.get_default_location ();
            if (root == null) {
                continue;
            }
            var uri = root.get_uri () ?? "";
            if (!uri.has_prefix ("mtp://") && !uri.has_prefix ("gphoto2://")) {
                continue;
            }

            if (pending_label == null) {
                pending_label = pick_label (mount);
                if (pending_label != null) {
                    print ("[MTP manager] System/Android label: %s\n", pending_label);
                }
            }

            print ("[MTP manager] Unmounting %s\n", uri);
            try {
                yield mount.unmount_with_operation (MountUnmountFlags.NONE, null, null);
            } catch (Error e) {
                print ("[MTP manager] Unmount: %s\n", e.message);
            }
        }
    }

    private void try_open_native (string reason) {
        if (busy || devices.size > 0 || announced) {
            return;
        }

        busy = true;
        print ("\n[MTP manager] Scan (%s)\n", reason);

        release_gvfs_mtp.begin ((obj, res) => {
            release_gvfs_mtp.end (res);
            Timeout.add (500, () => {
                open_session ();
                busy = false;
                return false;
            });
        });
    }

    private void open_session () {
        if (devices.size > 0 || announced) {
            return;
        }

        unowned Mtp.Device? raw = Mtp.get_first_device ();
        if (raw == null) {
            print ("[MTP manager] No libmtp device\n");
            return;
        }

        print ("[MTP manager] Session opened — registering device\n");

        var added = new AndroidDevice (raw, pending_label);
        devices.add (added);

        if (!added.start_initialization ()) {
            added.release_mtp ();
            devices.remove (added);
            return;
        }

        added.initialized.connect ((d) => {
            if (announced) {
                return;
            }
            announced = true;

            var android = (AndroidDevice) d;
            if (!android.is_supported) {
                return;
            }

            print ("[MTP manager] Ready: %s\n", android.get_display_name ());
            DeviceManager.get_default ().device_initialized ((Music.Device) d);
        });

        added.finish_initialization ();
    }
}
