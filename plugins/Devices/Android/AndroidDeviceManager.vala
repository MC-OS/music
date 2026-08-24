// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Chunk 1: detect MTP volumes/mounts and register AndroidDevice. */

public class Music.Plugins.AndroidDeviceManager : GLib.Object {
    private Gee.ArrayList<AndroidDevice> devices;
    private VolumeMonitor volume_monitor;
    private Cancellable mount_cancellable;

    public AndroidDeviceManager () {
        devices = new Gee.ArrayList<AndroidDevice> ();
        mount_cancellable = new Cancellable ();

        Mtp.init ();

        volume_monitor = VolumeMonitor.get ();
        volume_monitor.volume_added.connect (on_volume_added);
        foreach (var volume in volume_monitor.get_volumes ()) {
            on_volume_added (volume);
        }

        var device_manager = DeviceManager.get_default ();
        device_manager.mount_added.connect (mount_added);
        device_manager.mount_removed.connect (mount_removed);

        foreach (var mount in device_manager.get_available_mounts ()) {
            mount_added (mount);
        }
    }

    public void remove_all () {
        mount_cancellable.cancel ();

        var device_manager = DeviceManager.get_default ();
        foreach (var dev in devices) {
            dev.release_mtp ();
            device_manager.device_removed ((Music.Device) dev);
        }

        devices.clear ();
        mount_cancellable = new Cancellable ();
    }

    private bool volume_looks_mtp (Volume volume) {
        File? root = null;
        try {
            root = volume.get_activation_root ();
        } catch (Error e) {
            root = null;
        }

        if (root != null) {
            var uri = root.get_uri () ?? "";
            var parse = root.get_parse_name () ?? "";
            if (uri.has_prefix ("mtp://") || parse.has_prefix ("mtp://")
                || uri.has_prefix ("gphoto2://")) {
                return true;
            }
        }

        var id = volume.get_identifier (VolumeIdentifier.UNIX_DEVICE);
        var name = (volume.get_name () ?? "").down ();
        if (id != null && ("mtp" in id.down () || "gphoto" in id.down ())) {
            return true;
        }

        return "mtp" in name;
    }

    private void on_volume_added (Volume volume) {
        if (mount_cancellable.is_cancelled ()) {
            return;
        }

        if (volume.get_mount () != null || !volume.can_mount ()) {
            return;
        }

        if (!volume_looks_mtp (volume)) {
            return;
        }

        message ("Auto-mounting MTP volume: %s", volume.get_name () ?? "(unnamed)");
        volume.mount.begin (MountMountFlags.NONE, null, null, (obj, res) => {
            try {
                volume.mount.end (res);
            } catch (IOError.CANCELLED e) {
                debug ("MTP auto-mount cancelled");
            } catch (Error e) {
                warning ("MTP auto-mount failed: %s", e.message);
            }
        });
    }

    public void mount_added (Mount mount) {
        var root = mount.get_default_location ();
        if (root == null) {
            return;
        }

        var root_uri = root.get_uri ();
        foreach (var dev in devices) {
            if (dev.get_uri () == root_uri) {
                return;
            }
        }

        bool is_mtp = root_uri.has_prefix ("mtp://")
            || (root.get_parse_name () ?? "").has_prefix ("mtp://");
        bool is_android_layout =
            File.new_for_uri (root_uri + "/Android").query_exists ()
            || File.new_for_uri (root_uri + "/.is_android_device").query_exists ();

        if (!is_mtp && !is_android_layout) {
            return;
        }

        var added = new AndroidDevice (mount);
        devices.add (added);

        if (!added.start_initialization ()) {
            devices.remove (added);
            return;
        }

        added.finish_initialization ();
        added.initialized.connect ((d) => {
            var android = (AndroidDevice) d;
            if (android.is_supported) {
                message ("Android/MTP ready: %s", android.get_display_name ());
                DeviceManager.get_default ().device_initialized ((Music.Device) d);
            }
        });
    }

    public void mount_removed (Mount mount) {
        var root = mount.get_default_location ();
        if (root == null) {
            return;
        }

        var root_uri = root.get_uri ();
        var iter = devices.iterator ();
        while (iter.next ()) {
            var dev = iter.get ();
            if (dev.get_uri () == root_uri) {
                dev.release_mtp ();
                DeviceManager.get_default ().device_removed ((Music.Device) dev);
                iter.remove ();
                break;
            }
        }
    }
}
