// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Session-only MTP cache (Netflix-style while plugged in):
 *   1. Pull track into ~/.cache/io.elementary.music/mtp/ for seekable play.
 *   2. Reuse within the same session.
 *   3. Wipe that cache when the device unplugs — nothing left behind.
 */

public class Music.Plugins.AndroidStreamer : Music.Playback, GLib.Object {
    Music.Pipeline pipe;
    InstallGstreamerPluginsDialog dialog;
    public bool set_resume_pos;

    private AndroidDeviceManager manager;
    private static File cache_dir;

    public AndroidStreamer (AndroidDeviceManager manager) {
        this.manager = manager;
        pipe = new Music.Pipeline ();
        pipe.bus.add_watch (GLib.Priority.DEFAULT, bus_callback);
        Timeout.add (200, update_position);

        cache_dir = File.new_for_path (
            Path.build_filename (Environment.get_user_cache_dir (),
                                 "io.elementary.music", "mtp"));
        try {
            if (!cache_dir.query_exists ()) {
                cache_dir.make_directory_with_parents ();
            }
        } catch (Error e) {
            warning ("[MTP streamer] cache dir: %s", e.message);
        }
    }

    public Gee.Collection<string> get_supported_uri () {
        var uris = new Gee.LinkedList<string> ();
        uris.add ("mtp-native://");
        return uris;
    }

    /**
     * Delete cached tracks for one device (by serial), or the whole MTP
     * cache if serial is null/empty. Called on eject / unplug.
     */
    public static void wipe_cache (string? serial = null) {
        if (cache_dir == null) {
            cache_dir = File.new_for_path (
                Path.build_filename (Environment.get_user_cache_dir (),
                                     "io.elementary.music", "mtp"));
        }
        if (!cache_dir.query_exists ()) {
            return;
        }

        string? prefix = null;
        if (serial != null && serial.length > 0) {
            prefix = serial.replace ("/", "_").replace (" ", "_") + "-";
        }

        try {
            var enumerator = cache_dir.enumerate_children (
                FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                var name = info.get_name ();
                if (prefix != null && !name.has_prefix (prefix)) {
                    continue;
                }
                try {
                    cache_dir.get_child (name).delete ();
                } catch (Error e) {
                    warning ("[MTP streamer] wipe %s: %s", name, e.message);
                }
            }
            print ("[MTP streamer] Cache wiped%s\n",
                prefix != null ? " for device" : "");
        } catch (Error e) {
            warning ("[MTP streamer] wipe_cache: %s", e.message);
        }
    }

    public bool update_position () {
        if (set_resume_pos || (App.player.current_media != null && get_position () >= (int64)(App.player.current_media.resume_pos - 1) * 1000000000)) {
            set_resume_pos = true;
            current_position_update (get_position ());
        } else if (App.player.current_media != null) {
            pipe.playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, (int64)App.player.current_media.resume_pos * 1000000000);
        }
        return true;
    }

    public void play () {
        set_state (Gst.State.PLAYING);
    }

    public void pause () {
        set_state (Gst.State.PAUSED);
    }

    public void set_state (Gst.State s) {
        pipe.playbin.set_state (s);
    }

    public void set_media (Media media) {
        set_state (Gst.State.READY);

        string? local_uri = ensure_cached (media);
        if (local_uri == null) {
            warning ("[MTP streamer] Cache/download failed for %s", media.uri);
            error_occured ();
            return;
        }

        print ("[MTP streamer] Playing from cache: %s\n", local_uri);
        pipe.playbin.set_property ("uri", local_uri);
        set_state (Gst.State.PLAYING);
        pipe.playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH,
            (int64) App.player.current_media.resume_pos * 1000000000);
        play ();
    }

    private string? ensure_cached (Media media) {
        var android = manager.get_device_for_uri (media.uri);
        if (android == null) {
            warning ("[MTP streamer] No device for %s", media.uri);
            return null;
        }

        var lib = android.get_library () as AndroidLibrary;
        if (lib == null) {
            return null;
        }

        uint32 item_id = lib.get_item_id (media.uri);
        if (item_id == 0) {
            warning ("[MTP streamer] No item_id for %s", media.uri);
            return null;
        }

        string ext = extension_from_uri (media.uri);
        string serial = android.get_serial_number ();
        if (serial == null || serial.length == 0) {
            serial = "unknown";
        }
        string safe_serial = serial.replace ("/", "_").replace (" ", "_");
        string name = "%s-%u%s".printf (safe_serial, item_id, ext);
        File cached = cache_dir.get_child (name);

        if (cached.query_exists ()) {
            try {
                var info = cached.query_info (FileAttribute.STANDARD_SIZE, 0);
                if (info.get_size () > 0) {
                    print ("[MTP streamer] Cache hit: %s\n", cached.get_path ());
                    return cached.get_uri ();
                }
            } catch (Error e) {
            }
            try { cached.delete (); } catch (Error e) {}
        }

        unowned Mtp.Device? mtp = lib.get_mtp ();
        if (mtp == null) {
            warning ("[MTP streamer] MTP session is gone");
            return null;
        }

        string path = cached.get_path ();
        print ("[MTP streamer] Caching object %u → %s\n", item_id, path);
        int ret = mtp.get_file_to_file (item_id, path);
        if (ret != 0) {
            warning ("[MTP streamer] Get_File_To_File failed (%d)", ret);
            try { if (cached.query_exists ()) cached.delete (); } catch (Error e) {}
            return null;
        }

        print ("[MTP streamer] Cached object %u\n", item_id);
        return cached.get_uri ();
    }

    private static string extension_from_uri (string uri) {
        int dot = uri.last_index_of_char ('.');
        if (dot > 0 && uri.length - dot <= 5) {
            return uri.substring (dot).down ();
        }
        return ".bin";
    }

    public void set_position (int64 pos) {
        pipe.playbin.seek (1.0,
            Gst.Format.TIME, Gst.SeekFlags.FLUSH,
            Gst.SeekType.SET, pos,
            Gst.SeekType.NONE, get_duration ());
    }

    public int64 get_position () {
        int64 rv = 0;
        Gst.Format f = Gst.Format.TIME;
        pipe.playbin.query_position (f, out rv);
        return rv;
    }

    public int64 get_duration () {
        int64 rv = 0;
        Gst.Format f = Gst.Format.TIME;
        pipe.playbin.query_duration (f, out rv);
        return rv;
    }

    public void set_volume (double val) {
        pipe.playbin.set_property ("volume", val);
    }

    public double get_volume () {
        var val = GLib.Value (typeof (double));
        pipe.playbin.get_property ("volume", ref val);
        return (double) val;
    }

    public void enable_equalizer () {
        pipe.enable_equalizer ();
    }

    public void disable_equalizer () {
        pipe.disable_equalizer ();
    }

    public void set_equalizer_gain (int index, int val) {
        pipe.eq.set_gain (index, val);
    }

    private bool bus_callback (Gst.Bus bus, Gst.Message message) {
        switch (message.type) {
            case Gst.MessageType.ERROR:
                GLib.Error err;
                string debug;
                message.parse_error (out err, out debug);
                warning ("[MTP streamer] Error: %s\n", err.message);
                error_occured ();
                break;
            case Gst.MessageType.ELEMENT:
                if (message.get_structure () != null && Gst.PbUtils.is_missing_plugin_message (message) && (dialog == null || !dialog.visible)) {
                    dialog = new InstallGstreamerPluginsDialog (message);
                }
                break;
            case Gst.MessageType.EOS:
                end_of_stream ();
                break;
            default:
                break;
        }
        return true;
    }
}
