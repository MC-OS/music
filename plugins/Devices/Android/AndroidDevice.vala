// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Device + optional hardware fields for core DeviceSummaryWidget. */

public class Music.Plugins.AndroidDevice : GLib.Object, Music.Device {
    private Mount mount;
    private GLib.Icon icon;
    private AndroidLibrary library;

    private Mtp.Device? mtp_device = null;
    private string? mtp_friendly_name = null;
    private string? mtp_model_name = null;
    private string? mtp_manufacturer = null;
    private uint64 mtp_capacity = 0;
    private uint64 mtp_free = 0;

    private string? _serial = null;
    private string? _imei = null;
    private int _battery = -1;
    private string? _os_version = null;
    private string? _rom_name = null;
    private string? _security_patch = null;
    private string? _device_version = null;

    public bool is_supported = true;

    public AndroidDevice (Mount mount) {
        this.mount = mount;
        icon = new GLib.ThemedIcon ("phone");
        library = new AndroidLibrary (this);
        libraries_manager.add_library (library);
        try_open_mtp ();
        try_read_android_props ();
    }

    public override string? get_serial_number () {
        return _serial;
    }

    public override string? get_imei () {
        return _imei;
    }

    public override string? get_model_identifier () {
        if (mtp_model_name != null && mtp_model_name.strip ().length > 0) {
            if (mtp_manufacturer != null && mtp_manufacturer.strip ().length > 0
                && !mtp_model_name.down ().contains (mtp_manufacturer.down ())) {
                return "%s %s".printf (mtp_manufacturer, mtp_model_name);
            }

            return mtp_model_name;
        }

        return null;
    }

    public override int get_battery_percent () {
        return _battery;
    }

    public override string? get_os_version () {
        if (_os_version != null) {
            return _os_version;
        }

        return _device_version;
    }

    public override string? get_rom_name () {
        return _rom_name;
    }

    public override string? get_security_patch () {
        return _security_patch;
    }

    public override bool can_reset () {
        return true;
    }

    /** Backup + restore (+ encrypt) UI for Android. */
    public override bool can_recover () {
        return true;
    }

    // Actions stay overridable; defaults on Device show infobar until implemented.

    private bool is_generic_label (string? name) {
        if (name == null || name.strip ().length == 0) {
            return true;
        }

        var n = name.strip ().down ();
        return n == "mtp"
            || n == "mtp device"
            || n == "android"
            || n == "android device"
            || n.has_prefix ("mtp://")
            || n.has_prefix ("usb");
    }

    private void try_open_mtp () {
        release_mtp ();
        mtp_capacity = 0;
        mtp_free = 0;
        _battery = -1;

        Mtp.init ();
        mtp_device = Mtp.get_first_device ();
        if (mtp_device == null) {
            debug ("libmtp could not open device (GVFS may own it)");
            return;
        }

        var friendly = mtp_device.get_friendly_name ();
        var model = mtp_device.get_model_name ();
        var mfr = mtp_device.get_manufacturer_name ();
        var serial = mtp_device.get_serial_number ();
        var version = mtp_device.get_device_version ();

        if (friendly != null && friendly.strip ().length > 0) {
            mtp_friendly_name = friendly.strip ();
        }
        if (model != null && model.strip ().length > 0) {
            mtp_model_name = model.strip ();
        }
        if (mfr != null && mfr.strip ().length > 0) {
            mtp_manufacturer = mfr.strip ();
        }
        if (serial != null && serial.strip ().length > 0) {
            _serial = serial.strip ();
        }
        if (version != null && version.strip ().length > 0) {
            _device_version = version.strip ();
        }

        _imei = null;

        uint8 max_level = 0;
        uint8 cur_level = 0;
        if (mtp_device.get_battery_level (out max_level, out cur_level) == 0 && max_level > 0) {
            _battery = (int) ((cur_level * 100) / max_level);
        }

        if (mtp_device.get_storage (0) == 0 && mtp_device.storage != null) {
            unowned Mtp.Storage? store = mtp_device.storage;
            while (store != null) {
                var desc = (store.StorageDescription ?? "").down ();
                bool external = desc.contains ("sd") || desc.contains ("card")
                    || desc.contains ("external") || desc.contains ("removable");
                if (!external) {
                    mtp_capacity = store.MaxCapacity;
                    mtp_free = store.FreeSpaceInBytes;
                    break;
                }

                store = store.next;
            }

            if (mtp_capacity == 0 && mtp_device.storage != null) {
                mtp_capacity = mtp_device.storage.MaxCapacity;
                mtp_free = mtp_device.storage.FreeSpaceInBytes;
            }
        }

        DeviceManager.get_default ().device_name_changed (this);
    }

    private void try_read_android_props () {
        string[] candidates = {
            get_uri () + "/system/build.prop",
            get_uri () + "/build.prop"
        };

        foreach (var path in candidates) {
            var file = File.new_for_uri (path);
            if (!file.query_exists ()) {
                continue;
            }

            try {
                uint8[] data;
                file.load_contents (null, out data, null);
                var text = (string) data;
                foreach (var line in text.split ("\n")) {
                    var t = line.strip ();
                    if (t.has_prefix ("ro.build.version.release=")) {
                        _os_version = t.substring (t.index_of ("=") + 1).strip ();
                    } else if (t.has_prefix ("ro.build.version.security_patch=")) {
                        _security_patch = t.substring (t.index_of ("=") + 1).strip ();
                    } else if (t.has_prefix ("ro.modversion=")) {
                        if (_rom_name == null) {
                            _rom_name = t.substring (t.index_of ("=") + 1).strip ();
                        }
                    } else if (t.has_prefix ("ro.lineage.version=")) {
                        _rom_name = "LineageOS " + t.substring (t.index_of ("=") + 1).strip ();
                    } else if (t.has_prefix ("ro.lineage.display.version=")) {
                        _rom_name = "LineageOS " + t.substring (t.index_of ("=") + 1).strip ();
                    } else if (t.has_prefix ("ro.product.system.name=")) {
                        if (_rom_name == null) {
                            _rom_name = t.substring (t.index_of ("=") + 1).strip ();
                        }
                    } else if (t.has_prefix ("ro.build.display.id=")) {
                        if (_rom_name == null) {
                            _rom_name = t.substring (t.index_of ("=") + 1).strip ();
                        }
                    }
                }
            } catch (Error e) {
                debug ("build.prop: %s", e.message);
            }

            break;
        }
    }

    public void release_mtp () {
        if (mtp_device != null) {
            Mtp.release_device (mtp_device);
            mtp_device = null;
        }
    }

    public void notify_name_ready () {
        DeviceManager.get_default ().device_name_changed (this);
    }

    public bool start_initialization () {
        if (mount == null || mount.get_default_location () == null) {
            is_supported = false;
            return false;
        }

        is_supported = true;
        return true;
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
        if (!is_generic_label (mtp_friendly_name)) {
            return mtp_friendly_name;
        }

        var model_id = get_model_identifier ();
        if (model_id != null) {
            return model_id;
        }

        var volume = mount.get_volume ();
        if (volume != null) {
            var drive = volume.get_drive ();
            if (drive != null && !is_generic_label (drive.get_name ())) {
                return drive.get_name ().strip ();
            }

            if (!is_generic_label (volume.get_name ())) {
                return volume.get_name ().strip ();
            }
        }

        if (!is_generic_label (mount.get_name ())) {
            return mount.get_name ().strip ();
        }

        return _("Android MTP device");
    }

    public void set_display_name (string name) {
        try {
            mount.get_default_location ().set_display_name (name);
        } catch (Error err) {
            warning ("set_display_name: %s", err.message);
        }

        DeviceManager.get_default ().device_name_changed (this);
    }

    public string get_fancy_description () {
        return "";
    }

    public void set_mount (Mount mount) {
        this.mount = mount;
    }

    public Mount? get_mount () {
        return mount;
    }

    public string get_uri () {
        return mount.get_default_location ().get_uri ();
    }

    public void set_icon (GLib.Icon icon) {
        this.icon = icon;
    }

    public GLib.Icon get_icon () {
        return icon;
    }

    public uint64 get_capacity () {
        if (mtp_capacity > 0) {
            return mtp_capacity;
        }

        try {
            var info = File.new_for_uri (get_uri ()).query_filesystem_info ("filesystem::*", null);
            return info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
        } catch (Error e) {
            return 0;
        }
    }

    public string get_fancy_capacity () {
        return GLib.format_size (get_capacity ());
    }

    public uint64 get_used_space () {
        return get_capacity () - get_free_space ();
    }

    public uint64 get_free_space () {
        if (mtp_capacity > 0) {
            return mtp_free;
        }

        try {
            var info = File.new_for_uri (get_uri ()).query_filesystem_info ("filesystem::*", null);
            return info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
        } catch (Error e) {
            return 0;
        }
    }

    public void unmount () {
        release_mtp ();
        mount.unmount_with_operation.begin (MountUnmountFlags.NONE, null);
    }

    public void eject () {
        release_mtp ();
        if (mount.can_eject ()) {
            mount.get_volume ().get_drive ().eject_with_operation.begin (MountUnmountFlags.NONE, null);
        } else {
            unmount ();
        }
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
        return true;
    }
}
