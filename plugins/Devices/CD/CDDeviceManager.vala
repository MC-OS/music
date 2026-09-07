// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Watch for optical media and register a CDDevice when an audio CD appears.
 *
 * Initialization order matches iPodDeviceManager / AudioPlayerDeviceManager:
 *   create device → start_initialization → connect initialized →
 *   finish_initialization → DeviceManager.device_initialized
 */

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
            dev.release ();
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

    private bool is_optical (Volume volume) {
        var drive = volume.get_drive ();
        if (drive == null) {
            return false;
        }

        /* Prefer explicit optical identification when available */
        if (drive.has_media () && drive.can_eject ()) {
            string? unix = volume.get_identifier ("unix-device");
            if (unix != null && (unix.has_prefix ("/dev/sr") || unix.has_prefix ("/dev/cd"))) {
                return true;
            }
        }

        return drive.is_media_removable () && drive.has_media () && drive.can_eject ();
    }

    public virtual void volume_added (Volume volume) {
        if (!is_optical (volume)) {
            return;
        }

        foreach (var dev in devices) {
            if (dev.get_volume () == volume) {
                return;
            }
        }

        message ("[CD] Optical volume detected: %s (%s)",
                 volume.get_name () ?? "(unnamed)",
                 volume.get_identifier ("unix-device") ?? "?");

        var added = new CDDevice (volume);
        devices.add (added);

        if (added.start_initialization ()) {
            /* MUST connect before finish_initialization – CD emits initialized quickly */
            added.initialized.connect ((d) => {
                message ("[CD] device initialized: %s", d.get_display_name ());
                DeviceManager.get_default ().device_initialized ((Music.Device) d);
            });
            added.finish_initialization ();
        }
    }

    public virtual void mount_added (Mount mount) {
        var volume = mount.get_volume ();
        if (volume != null) {
            volume_added (volume);
        }
    }

    public virtual void volume_removed (Volume volume) {
        var device_manager = DeviceManager.get_default ();
        foreach (var dev in devices) {
            if (dev.get_volume () == volume) {
                message ("[CD] volume removed: %s", volume.get_name () ?? "?");
                device_manager.device_removed ((Music.Device) dev);
                dev.release ();
                devices.remove (dev);
                return;
            }
        }
    }

    public virtual void mount_removed (Mount mount) {
        var volume = mount.get_volume ();
        if (volume != null) {
            volume_removed (volume);
        }
    }
}
