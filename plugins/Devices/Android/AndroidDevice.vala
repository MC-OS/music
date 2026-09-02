// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Music.Device for a native libmtp session (no GVFS mount required). */

public class Music.Plugins.AndroidDevice : GLib.Object, Music.Device {
    private unowned Mtp.Device? mtp;
    private GLib.Icon icon;
    private AndroidLibrary library;

    /* User-facing name from Android (MTP Friendly Device Name) */
    private string friendly = "";
    /* GVFS/volume label captured before unmount (often the Android device name) */
    private string system_label = "";
    private string manufacturer = "";
    private string model = "";
    private string serial = "";
    /* MTP Deviceversion string (almost always "1.0") — not the Android OS version. */
    private string device_version = "";
    private int battery = -1;
    private uint64 capacity = 0;
    private uint64 free_space = 0;
    private string uri_id;
    private uint32 internal_storage_id = 0;
    /* MTP Perceived Device Type (0xD407), read from the device itself. */
    private uint32 perceived_type = 0;
    private uint64[] storage_info = { 0, 0, 0, 0, 0 };
    private bool storage_info_set = false;

    public bool is_supported = true;

    public AndroidDevice (unowned Mtp.Device device, string? system_device_label = null) {
        mtp = device;
        uri_id = "mtp-native://session";

        if (system_device_label != null) {
            system_label = clean_label (system_device_label);
        }

        refresh_from_mtp ();
        icon = new GLib.ThemedIcon (pick_icon_name ());

        library = new AndroidLibrary (this);
        libraries_manager.add_library (library);
    }

    /*
     * Icon from the device's own MTP Perceived Device Type (0xD407).
     * No name matching — the device reports its category itself.
     *   1 = Still Image/Video Camera → camera-photo-symbolic
     *   2 = Media (Audio/Video) Player → multimedia-player-symbolic
     *   3 = Mobile Handset            → phone
     *   4 = Video Player              → multimedia-player-symbolic
     *   5 = PIM / PDA                 → phone
     *   6 = Audio Recorder            → multimedia-player-symbolic
     *   0 / unknown                  → media-flash
     */
    private string pick_icon_name () {
        switch (perceived_type) {
            case 1: /* Still Image/Video Camera */
                return "camera-photo-symbolic";
            case 2: /* Media (Audio/Video) Player */
            case 4: /* Video Player */
            case 6: /* Audio Recorder */
                return "multimedia-player-symbolic";
            case 0: /* Generic */
            case 3: /* Mobile Handset */
            case 5: /* PIM / PDA */
                return "phone";
            default:
                return "media-flash";
        }
    }

    private static bool is_generic_label (string name) {
        var n = name.strip ().down ();
        if (n.length == 0) {
            return true;
        }
        return n == "mtp"
            || n == "mtp device"
            || n == "android"
            || n == "android device"
            || n == "android mtp device"
            || n.has_prefix ("mtp://")
            || n.has_prefix ("usb");
    }

    private static string clean_label (string name) {
        var t = name.strip ();
        /* mtp://SAMSUNG_Samsung_Galaxy_Tab_E_xxxx → try last path-ish segment */
        if ("mtp://" in t || "gphoto2://" in t) {
            try {
                var f = File.new_for_uri (t);
                var parse = f.get_parse_name () ?? t;
                var parts = parse.split ("/");
                if (parts.length > 0) {
                    t = parts[parts.length - 1];
                }
            } catch (Error e) {
            }
        }
        t = t.replace ("_", " ").strip ();
        return t;
    }

    private void refresh_from_mtp () {
        unowned Mtp.Device? d = mtp;
        if (d == null) {
            return;
        }

        unowned string? s;
        s = d.get_friendly_name ();
        if (s != null && s.strip ().length > 0) {
            friendly = s.strip ();
        }
        print ("[MTP] Friendly Device Name (Android): '%s'\n", friendly.length > 0 ? friendly : "(not set)");

        s = d.get_manufacturer_name ();
        if (s != null) {
            manufacturer = s.strip ();
        }
        s = d.get_model_name ();
        if (s != null) {
            model = s.strip ();
        }
        s = d.get_serial_number ();
        if (s != null && s.length > 0) {
            serial = s;
            uri_id = "mtp-native://%s".printf (serial);
        }
        s = d.get_device_version ();
        if (s != null) {
            device_version = s.strip ();
        }

        uint8 max_level = 0;
        uint8 cur_level = 0;
        if (d.get_battery_level (out max_level, out cur_level) == 0 && max_level > 0) {
            battery = (int) ((cur_level * 100) / max_level);
        }

        /* MTP Perceived Device Type — object 0 = the device itself.
         * libmtp has no Property enum, so pass the raw MTP code 0xD407. */
        perceived_type = d.get_u32_from_object (0, 0xD407, 0);
        print ("[MTP] Perceived Device Type: %u → icon '%s'\n", perceived_type, pick_icon_name ());

        capacity = 0;
        free_space = 0;
        internal_storage_id = 0;
        if (d.get_storage (0) == 0 && d.storage != null) {
            unowned Mtp.Storage? store = d.storage;
            while (store != null) {
                var desc = (store.StorageDescription ?? "").down ();
                bool external = desc.contains ("sd") || desc.contains ("card")
                    || desc.contains ("external") || desc.contains ("removable");
                if (!external && store.MaxCapacity > capacity) {
                    capacity = store.MaxCapacity;
                    free_space = store.FreeSpaceInBytes;
                    internal_storage_id = store.id;
                }
                store = store.next;
            }
            if (capacity == 0 && d.storage != null) {
                capacity = d.storage.MaxCapacity;
                free_space = d.storage.FreeSpaceInBytes;
                internal_storage_id = d.storage.id;
            }
        }
    }

    /* Drop the libmtp session, wipe session playback cache, remove from sidebar. */
    public void release_mtp () {
        /* Session-only cache: nothing left after unplug */
        AndroidStreamer.wipe_cache (serial);

        unowned Mtp.Device? d = mtp;
        if (d != null) {
            mtp = null;
            Mtp.release_device (d);
            print ("[MTP] Session released for %s\n", get_display_name ());
        }
        try {
            DeviceManager.get_default ().device_removed ((Music.Device) this);
        } catch (Error e) {
        }
    }

    public unowned Mtp.Device? get_mtp_device () {
        return mtp;
    }

    public uint32 get_internal_storage_id () {
        return internal_storage_id;
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

    /* ---------- Device interface: every string getter is wired ---------- */

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
        /* 1) Name set on the phone (MTP Friendly Device Name) */
        if (friendly.length > 0 && !is_generic_label (friendly)) {
            return friendly;
        }
        /* 2) System/volume label (often mirrors Android device name) */
        if (system_label.length > 0 && !is_generic_label (system_label)) {
            return system_label;
        }
        /* 3) Last resort: model */
        if (model.length > 0) {
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

    /*
     * IMEI is not exposed by the standard MTP property set that Android
     * implements. Always empty for pure-libmtp devices.
     */
    public string get_imei () {
        return "";
    }

    public string get_model_identifier () {
        return model;
    }

    public int get_battery_percent () {
        return battery;
    }

    /*
     * Real Android OS version is not available via standard MTP.
     * The old code returned MTP Deviceversion (almost always "1.0"),
     * which is misleading. Return empty so the UI shows a clean blank.
     */
    public string get_os_version () {
        return "";
    }

    /*
     * ROM / custom firmware name (Lineage, LFR, etc.) is not available
     * through standard MTP properties.
     */
    public string get_rom_name () {
        return "";
    }

    /*
     * Android security patch level is not exposed by MTP.
     */
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

    /*
     * [0] AUDIO [1] VIDEO [2] PHOTO [3] APP [4] OTHER
     * APP is always 0 over MTP. OTHER closes the gap to used space.
     */
    public uint64[] get_device_storage_info () {
        if (storage_info_set) {
            return storage_info;
        }

        uint64 audio = 0;
        uint64 video = 0;
        uint64 photo = 0;
        uint64 other = 0;

        if (library != null) {
            foreach (var m in library.get_medias ()) {
                if (m == null || m.file_size == 0) {
                    continue;
                }
                var uri = (m.uri ?? "").down ();
                if (uri.has_suffix (".mp3") || uri.has_suffix (".flac") || uri.has_suffix (".m4a")
                    || uri.has_suffix (".ogg") || uri.has_suffix (".wav") || uri.has_suffix (".aac")
                    || uri.has_suffix (".opus") || uri.has_suffix (".wma") || uri.has_suffix (".aiff")) {
                    audio += m.file_size;
                } else if (uri.has_suffix (".mp4") || uri.has_suffix (".mkv") || uri.has_suffix (".avi")
                    || uri.has_suffix (".mov") || uri.has_suffix (".webm") || uri.has_suffix (".3gp")
                    || uri.has_suffix (".m4v") || uri.has_suffix (".wmv")) {
                    video += m.file_size;
                } else if (uri.has_suffix (".jpg") || uri.has_suffix (".jpeg") || uri.has_suffix (".png")
                    || uri.has_suffix (".gif") || uri.has_suffix (".webp") || uri.has_suffix (".heic")
                    || uri.has_suffix (".bmp") || uri.has_suffix (".tif") || uri.has_suffix (".tiff")) {
                    photo += m.file_size;
                } else {
                    other += m.file_size;
                }
            }
        }

        uint64 accounted = audio + video + photo + other;
        uint64 used = get_used_space ();
        if (used > accounted) {
            other += used - accounted;
        }

        return new uint64[] { audio, video, photo, 0, other };
    }

    public void set_device_storage_info (uint64[] info) {
        if (info != null && info.length >= 5) {
            storage_info = info;
            storage_info_set = true;
        }
    }

    public uint64 get_capacity () {
        return capacity;
    }

    public string get_fancy_capacity () {
        if (capacity == 0) {
            return "";
        }
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

    /* Eject / unmount: release the libmtp session and remove from the sidebar. */
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
