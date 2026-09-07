// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Watch for optical media via GVolumeMonitor (GVFS) and register CDDevice. */

public class Music.Plugins.CDDeviceManager : GLib.Object {
    Gee.ArrayList<CDDevice> devices;
    CDStreamer streamer;
    VolumeMonitor volume_monitor;

    public CDDeviceManager () {
        devices = new Gee.ArrayList<CDDevice> ();

        streamer = new CDStreamer (this);
        Music.App.player.add_playback (streamer);

        volume_monitor = VolumeMonitor.get ();
        volume_monitor.volume_added.connect (volume_added);
        volume_monitor.volume_removed.connect (volume_removed);
        volume_monitor.mount_added.connect (mount_added);
        volume_monitor.mount_removed.connect (mount_removed);

        foreach (var vol in volume_monitor.get_volumes ()) {
            volume_added (vol);
        }
    }

    public void remove_all () {
        var device_manager = DeviceManager.get_default ();
        foreach (var dev in devices) {
            device_manager.device_removed ((Music.Device) dev);
        }
        devices = new Gee.ArrayList<CDDevice> ();
    }

    public CDDevice? get_device_for_uri (string uri) {
        foreach (var device in devices) {
            if (device.get_library ().media_from_uri (uri) != null) {
                return device;
            }
            if (uri.has_prefix ("cdda://") || uri.has_prefix ("cd://")) {
                return device;
            }
        }
        return null;
    }

    private bool is_optical (Volume vol) {
        var drive = vol.get_drive ();
        if (drive == null) {
            return false;
        }

        if (!drive.has_media ()) {
            return false;
        }

        /* Copy into a non-null local to avoid Vala ownership free bugs */
        string device_path = vol.get_identifier ("unix-device") ?? "";
        if (device_path.has_prefix ("/dev/sr") || device_path.has_prefix ("/dev/cd")) {
            return true;
        }

        return drive.is_media_removable () && drive.can_eject ();
    }

    public virtual void volume_added (Volume vol) {
        if (!is_optical (vol)) {
            return;
        }

        foreach (var dev in devices) {
            if (dev.get_volume () == vol) {
                return;
            }
        }

        string device_path = vol.get_identifier ("unix-device") ?? "?";
        message ("[CD] Optical volume: %s (%s)",
                 vol.get_name () ?? "(unnamed)",
                 device_path);

        var added = new CDDevice (vol);
        devices.add (added);

        if (added.start_initialization ()) {
            added.initialized.connect ((d) => {
                message ("[CD] initialized: %s", d.get_display_name ());
                DeviceManager.get_default ().device_initialized ((Music.Device) d);
            });
            added.finish_initialization ();
        }
    }

    public virtual void mount_added (Mount mount) {
        var vol = mount.get_volume ();
        if (vol != null) {
            volume_added (vol);
        }
    }

    public virtual void volume_removed (Volume vol) {
        foreach (var dev in devices) {
            if (dev.get_volume () == vol) {
                DeviceManager.get_default ().device_removed ((Music.Device) dev);
                devices.remove (dev);
                return;
            }
        }
    }

    public virtual void mount_removed (Mount mount) {
        var vol = mount.get_volume ();
        if (vol != null) {
            volume_removed (vol);
        }
    }
}
