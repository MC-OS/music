// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Thin Device wrapper for an audio CD.
 *
 * Method order and initialization flow match iPodDevice / AudioPlayerDevice:
 *   construct → start_initialization → finish_initialization →
 *   initialized → library ready for the UI.
 *
 * only_use_custom_view() is true so LibraryWindow opens the CD library
 * list (DeviceViewWrapper) instead of the device summary page.
 */

public class Music.Plugins.CDDevice : GLib.Object, Music.Device {
    Volume volume;
    GLib.Icon icon;
    string display_name;
    CDLibrary library;

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
        return "cdda://" + get_serial_number ();
    }

    public string get_serial_number () {
        return volume.get_identifier ("uuid")
            ?? volume.get_identifier ("unix-device")
            ?? "cdrom";
    }

    public void set_icon (GLib.Icon icon) {
        this.icon = icon;
    }

    public GLib.Icon get_icon () {
        return icon;
    }

    public uint64 get_capacity () {
        return 0;
    }

    public string get_fancy_capacity () {
        return "";
    }

    public uint64 get_used_space () {
        return 0;
    }

    public uint64 get_free_space () {
        return 0;
    }

    public uint64[] get_device_storage_info () {
        return new uint64[] { 0, 0, 0, 0, 0 };
    }

    public void set_device_storage_info (uint64[] info) {
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

    public bool only_use_custom_view () {
        return true;
    }

    public Gtk.Widget? get_custom_view () {
        /* Opening the CD starts the lazy TOC scan */
        library.ensure_scanned ();

        var tvs = new TreeViewSetup (ViewWrapper.Hint.CDROM);
        return new DeviceViewWrapper (tvs, this, library);
    }

    public bool read_only () {
        return true;
    }

    public Music.Library get_library () {
        return library;
    }

    public void release () {
    }

    public string get_imei () { return ""; }
    public string get_model_identifier () { return "Audio CD"; }
    public int get_battery_percent () { return -1; }
    public string get_os_version () { return ""; }
    public string get_rom_name () { return ""; }
    public string get_security_patch () { return ""; }
}
