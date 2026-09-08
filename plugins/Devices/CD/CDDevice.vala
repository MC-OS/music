// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Audio CD device.
 *
 * Mirrors AudioPlayerDevice: only_use_custom_view() is false and
 * get_custom_view() returns null, so the normal DeviceSummaryWidget
 * renders under the CD icon. Track list uses DeviceViewWrapper with
 * DEVICE_AUDIO (Import to Library works via transfer_to_local_library).
 */

public class Music.Plugins.CDDevice : GLib.Object, Music.Device {
    Volume volume;
    GLib.Icon icon;
    string display_name;
    CDLibrary library;

    /* Blank audio CD: 74:33 @ 44100 Hz 16-bit stereo (~80 min Red Book). */
    private const uint64 CD_CAPACITY = 681984000;
    private const uint BYTES_PER_SECTOR = 2352;
    private const uint SECTORS_PER_SEC = 75;

    public CDDevice (Volume volume) {
        this.volume = volume;
        display_name = volume.get_name () ?? _("Audio CD");
        icon = new ThemedIcon ("media-optical");
    }

    public bool start_initialization () {
        library = new CDLibrary (this);
        libraries_manager.add_library (library);
        return true;
    }

    public void finish_initialization () {
        library.finish_initialization_async.begin ();
    }

    public string get_empty_device_title () {
        return _("No audio tracks");
    }

    public string get_empty_device_description () {
        return _("This disc does not contain any audio tracks.");
    }

    public string get_content_type () {
        return "cdrom";
    }

    public string get_display_name () {
        return display_name;
    }

    public void set_display_name (string name) {
        display_name = name;
        DeviceManager.get_default ().device_name_changed (this);
    }

    public string get_fancy_description () {
        return _("Audio CD");
    }

    public void set_mount (Mount mount) {
    }

    public Mount? get_mount () {
        return volume.get_mount ();
    }

    public Volume get_volume () {
        return volume;
    }

    public string get_uri () {
        string? unix_device = volume.get_identifier ("unix-device");
        if (unix_device != null && unix_device.has_prefix ("/dev/")) {
            string device_name = unix_device.substring (5);
            return "cdda://%s/".printf (device_name);
        }

        return "cdda://";
    }

    public void set_icon (GLib.Icon icon) {
        this.icon = icon;
    }

    public GLib.Icon get_icon () {
        return icon;
    }

    public uint64 get_capacity () {
        return CD_CAPACITY;
    }

    public string get_fancy_capacity () {
        return _("80 min");
    }

    public uint64 get_used_space () {
        uint64 used = 0;
        foreach (var m in library.get_medias ()) {
            if (m.file_size > 0) {
                used += m.file_size;
            } else {
                double secs = m.length > 0 ? m.length / 1000.0 : 240.0;
                used += (uint64) (secs * SECTORS_PER_SEC * BYTES_PER_SECTOR);
            }
        }
        return used;
    }

    public uint64 get_free_space () {
        uint64 used = get_used_space ();
        return CD_CAPACITY > used ? CD_CAPACITY - used : 0;
    }

    public void unmount () {
        var mount = volume.get_mount ();
        if (mount != null) {
            mount.unmount_with_operation.begin (MountUnmountFlags.NONE, null, null);
        }
    }

    public void eject () {
        var drive = volume.get_drive ();
        if (drive != null && drive.can_eject ()) {
            drive.eject_with_operation.begin (MountUnmountFlags.NONE, null, null);
        }
    }

    public void synchronize () {
    }

    /* Match AudioPlayerDevice: normal summary + library list under the icon. */
    public bool only_use_custom_view () {
        return false;
    }

    /* Burn-CD UI reserved for later; not wired in yet. */
    public Gtk.Widget? get_custom_view () {
        return null;
    }

    public bool read_only () {
        return true;
    }

    public Music.Library get_library () {
        return library;
    }
}
