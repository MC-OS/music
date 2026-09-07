// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Thin Device wrapper for an audio CD.
 *
 * get_custom_view() returns a DeviceViewWrapper so DeviceView never
 * attaches the DeviceSummaryWidget (storage bar, sync options, etc.).
 * The user only sees the track library and can import from it.
 */

public class Music.Plugins.CDDevice : GLib.Object, Music.Device {
    private Volume volume;
    private CDLibrary library;
    private GLib.Icon icon;
    private string display_name;

    public CDDevice (Volume volume) {
        this.volume = volume;
        display_name = volume.get_name () ?? _("Audio CD");
        icon = new ThemedIcon ("media-optical");

        library = new CDLibrary (this);
        libraries_manager.add_library (library);
    }

    public Volume get_volume () {
        return volume;
    }

    public void release () {
    }

    public bool start_initialization () {
        return true;
    }

    public void finish_initialization () {
        library.finish_initialization_async.begin ();
    }

    public Library get_library () {
        return library;
    }

    public string get_content_type () {
        return "cdrom";
    }

    public string get_display_name () {
        return display_name;
    }

    public void set_display_name (string name) {
        display_name = name;
    }

    public string get_serial_number () {
        return volume.get_identifier ("uuid") ?? volume.get_identifier ("unix-device") ?? "cdrom";
    }

    public string get_uri () {
        return "cdda://" + get_serial_number ();
    }

    public GLib.Icon get_icon () {
        return icon;
    }

    public void set_icon (GLib.Icon icon) {
        this.icon = icon;
    }

    /* Still return true for any future callers that check the flag */
    public bool only_use_custom_view () {
        return true;
    }

    public Gtk.Widget? get_custom_view () {
        /* Non-null widget makes DeviceView skip the summary page entirely */
        var tvs = new TreeViewSetup (ViewWrapper.Hint.CDROM);
        return new DeviceViewWrapper (tvs, this, library);
    }

    public string get_empty_device_title () {
        return _("No audio tracks");
    }

    public string get_empty_device_description () {
        return _("This disc does not contain any audio tracks.");
    }

    public string get_fancy_description () {
        return _("Audio CD");
    }

    public uint64 get_capacity () { return 0; }
    public uint64 get_used_space () { return 0; }
    public uint64 get_free_space () { return 0; }
    public string get_fancy_capacity () { return ""; }

    public uint64[] get_device_storage_info () {
        return new uint64[] { 0, 0, 0, 0, 0 };
    }

    public void set_device_storage_info (uint64[] info) {
    }

    public void set_mount (Mount mount) {
    }

    public Mount? get_mount () {
        return volume.get_mount ();
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

    public bool read_only () {
        return true;
    }

    public string get_imei () { return ""; }
    public string get_model_identifier () { return "Audio CD"; }
    public int get_battery_percent () { return -1; }
    public string get_os_version () { return ""; }
    public string get_rom_name () { return ""; }
    public string get_security_patch () { return ""; }
}
