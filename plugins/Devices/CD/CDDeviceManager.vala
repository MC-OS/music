// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Watch for optical media and register a CDDevice when an audio CD appears. */

public class Music.Plugins.CDDeviceManager : GLib.Object {
    private Gee.ArrayList<CDDevice> devices;
    private VolumeMonitor volume_monitor;
    private CDStreamer streamer;

    public CDDeviceManager () {
        devices = new Gee.ArrayList<CDDevice> ();

        streamer = new CDStreamer (this);
        Music.App.player.add_playback (streamer);

        volume_monitor = VolumeMonitor.get ();
        volume_monitor.volume_added.connect (on_volume_added);
        volume_monitor.mount_added.connect (on_mount_added);
        volume_monitor.volume_removed.connect (on_volume_removed);
        volume_monitor.mount_removed.connect (on_mount_removed);

        foreach (var vol in volume_monitor.get_volumes ()) {
            on_volume_added (vol);
        }
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
        return drive.is_media_removable () && drive.has_media ();
    }

    private void on_volume_added (Volume volume) {
        if (!is_optical (volume)) {
            return;
        }

        foreach (var d in devices) {
            if (d.get_volume () == volume) {
                return;
            }
        }

        print ("[CD] Optical volume detected: %s\n", volume.get_name () ?? "(unnamed)");

        var device = new CDDevice (volume);
        devices.add (device);

        if (device.start_initialization ()) {
            device.initialized.connect ((d) => {
                DeviceManager.get_default ().device_initialized ((Music.Device) d);
            });
            device.finish_initialization ();
        }
    }

    private void on_mount_added (Mount mount) {
        var volume = mount.get_volume ();
        if (volume != null) {
            on_volume_added (volume);
        }
    }

    private void on_volume_removed (Volume volume) {
        CDDevice? to_remove = null;
        foreach (var d in devices) {
            if (d.get_volume () == volume) {
                to_remove = d;
                break;
            }
        }
        if (to_remove != null) {
            print ("[CD] Volume removed\n");
            to_remove.release ();
            devices.remove (to_remove);
            DeviceManager.get_default ().device_removed ((Music.Device) to_remove);
        }
    }

    private void on_mount_removed (Mount mount) {
        var volume = mount.get_volume ();
        if (volume != null) {
            on_volume_removed (volume);
        }
    }

    public void remove_all () {
        foreach (var d in devices) {
            d.release ();
            DeviceManager.get_default ().device_removed ((Music.Device) d);
        }
        devices.clear ();
    }
}
