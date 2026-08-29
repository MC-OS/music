// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Music.Device for a native libmtp session (no GVFS mount required). */

public class Music.Plugins.AndroidDevice : GLib.Object, Music.Device {
    private unowned Mtp.Device? mtp;
    private GLib.Icon icon;
    private AndroidLibrary library;

    private string friendly = "";
    private string manufacturer = "";
    private string model = "";
    private string serial = "";
    private string device_version = "";
    private int battery = -1;
    private uint64 capacity = 0;
    private uint64 free_space = 0;
    private string uri_id;

    public bool is_supported = true;

    public AndroidDevice (unowned Mtp.Device device) {
        mtp = device;
        icon = new GLib.ThemedIcon ("phone");
        uri_id = "mtp-native://session";

        refresh_from_mtp ();

        library = new AndroidLibrary (this);
        libraries_manager.add_library (library);
    }

    private void refresh_from_mtp () {
        unowned Mtp.Device? d = mtp;
        if (d == null) {
            return;
        }

        unowned string? s;
        s = d.get_friendly_name ();
        if (s != null && s.length > 0) {
            friendly = s;
        }
        s = d.get_manufacturer_name ();
        if (s != null) {
            manufacturer = s;
        }
        s = d.get_model_name ();
        if (s != null) {
            model = s;
        }
        s = d.get_serial_number ();
        if (s != null && s.length > 0) {
            serial = s;
            uri_id = "mtp-native://%s".printf (serial);
        }
        s = d.get_device_version ();
        if (s != null) {
            device_version = s;
        }

        uint8 max_level = 0;
        uint8 cur_level = 0;
        if (d.get_battery_level (out max_level, out cur_level) == 0 && max_level > 0) {
            battery = (int) ((cur_level * 100) / max_level);
        }

        capacity = 0;
        free_space = 0;
        if (d.get_storage (0) == 0 && d.storage != null) {
            unowned Mtp.Storage? store = d.storage;
            while (store != null) {
                var desc = (store.StorageDescription ?? "").down ();
                bool external = desc.contains ("sd") || desc.contains ("card")
                    || desc.contains ("external") || desc.contains ("removable");
                if (!external && store.MaxCapacity > capacity) {
                    capacity = store.MaxCapacity;
                    free_space = store.FreeSpaceInBytes;
                }
                store = store.next;
            }
            if (capacity == 0 && d.storage != null) {
                capacity = d.storage.MaxCapacity;
                free_space = d.storage.FreeSpaceInBytes;
            }
        }
    }

    public void release_mtp () {
        unowned Mtp.Device? d = mtp;
        if (d != null) {
            mtp = null;
            Mtp.release_device (d);
        }
    }

    public bool start_initialization () {
        return mtp != null;
    }

    public void finish_initialization () {
        library.finish_initialization_async.begin ();
    }

    public Library get_library () {
        return library;
    }

    public string get_empty_device_title () {
        return _("Empty device!");
    }

    public string get_empty_device_description () {
        return _("This device does not contain any music.");
    }

    public string get_content_type () {
        return "android-mtp";
    }

    public string get_display_name () {
        if (friendly.length > 0) {
            return friendly;
        }
        if (model.length > 0) {
            if (manufacturer.length > 0 && !model.down ().contains (manufacturer.down ())) {
                return "%s %s".printf (manufacturer, model);
            }
            return model;
        }
        return _("Android MTP device");
    }

    public void set_display_name (string name) {
        unowned Mtp.Device? d = mtp;
        if (d == null) {
            return;
        }
        if (d.set_friendly_name (name) == 0) {
            friendly = name;
            DeviceManager.get_default ().device_name_changed (this);
            print ("[MTP] Friendly name set to: %s\n", name);
        } else {
            warning ("LIBMTP_Set_Friendlyname failed");
        }
    }

    public string get_serial_number () {
        return serial;
    }

    public string get_imei () {
        return "";
    }

    public string get_model_identifier () {
        if (model.length == 0) {
            return "";
        }
        if (manufacturer.length > 0) {
            return "%s %s".printf (manufacturer, model);
        }
        return model;
    }

    public int get_battery_percent () {
        return battery;
    }

    public string get_os_version () {
        return device_version;
    }

    public string get_rom_name () {
        return "";
    }

    public string get_security_patch () {
        return "";
    }

    public string get_fancy_description () {
        return get_model_identifier ();
    }

    public void set_mount (Mount mount) {
    }

    public Mount? get_mount () {
        return null;
    }

    public string get_uri () {
        return uri_id;
    }

    public void set_icon (GLib.Icon icon) {
        this.icon = icon;
    }

    public GLib.Icon get_icon () {
        return icon;
    }

    public uint64 get_capacity () {
        return capacity;
    }

    public string get_fancy_capacity () {
        return GLib.format_size (capacity);
    }

    public uint64 get_used_space () {
        if (capacity < free_space) {
            return 0;
        }
        return capacity - free_space;
    }

    public uint64 get_free_space () {
        return free_space;
    }

    public void unmount () {
        release_mtp ();
    }

    public void eject () {
        release_mtp ();
    }

    public void synchronize () {
    }

    public bool only_use_custom_view () {
        return false;
    }

    public Gtk.Widget? get_custom_view () {
        return null;
    }

    public bool read_only () {
        return false;
    }
}
