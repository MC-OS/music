// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Discover via libmtp (uncached) so file listing works, register at most one AndroidDevice. */

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
                open_session_uncached ();
                busy = false;
                return false;
            });
        });
    }

    /*
     * Open via Detect_Raw_Devices + Open_Raw_Device_Uncached so
     * Get_Files_And_Folders works (cached sessions reject file listing).
     */
    private void open_session_uncached () {
        if (devices.size > 0 || announced) {
            return;
        }

        Mtp.RawDevice* rawdevs = null;
        int numdevs = 0;
        if (Mtp.Device.detect_raw_devices (out rawdevs, out numdevs) != 0 || numdevs <= 0 || rawdevs == null) {
            print ("[MTP manager] No raw MTP device detected\n");
            return;
        }

        unowned Mtp.Device? raw = Mtp.Device.open_raw_device_uncached (rawdevs[0]);
        if (raw == null) {
            print ("[MTP manager] Open_Raw_Device_Uncached failed\n");
            return;
        }

        print ("[MTP manager] Uncached session opened — registering device\n");

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

    /*
     * Called when the device is ejected/unplugged: drop it from our list and
     * re-arm scanning so a replug is detected. DeviceManager.device_removed is
     * fired by AndroidDevice.release_mtp() itself.
     */
    public void on_device_gone (AndroidDevice dev) {
        if (!devices.remove (dev)) {
            return;
        }
        announced = false;
        busy = false;
        pending_label = null;
        schedule_scan ("replug");
    }
}
