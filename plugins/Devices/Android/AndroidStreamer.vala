// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Playback for mtp-native:// — same approach as iPodStreamer:
 * point GStreamer at the GVFS mount path. No file is copied to disk.
 */

public class Music.Plugins.AndroidStreamer : Music.Playback, GLib.Object {
    Music.Pipeline pipe;
    InstallGstreamerPluginsDialog dialog;
    public bool set_resume_pos;

    public AndroidStreamer () {
        pipe = new Music.Pipeline ();
        pipe.bus.add_watch (GLib.Priority.DEFAULT, bus_callback);
        Timeout.add (200, update_position);
    }

    public Gee.Collection<string> get_supported_uri () {
        var uris = new Gee.LinkedList<string> ();
        uris.add ("mtp-native://");
        return uris;
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

        string play_uri = resolve_gvfs_uri (media);
        if (play_uri == null) {
            warning ("[MTP streamer] Could not resolve GVFS path for %s", media.uri);
            error_occured ();
            return;
        }

        debug ("[MTP streamer] set uri to %s\n", play_uri);
        pipe.playbin.set_property ("uri", play_uri.replace ("#", "%23"));
        set_state (Gst.State.PLAYING);
        pipe.playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, (int64)App.player.current_media.resume_pos * 1000000000);
        play ();
    }

    /*
     * iPod-style resolution:
     *   media.uri = mtp-native://SERIAL/Music/Artist/Song.mp3
     *   → file:///home/user/.gvfs/<MountName>/Music/Artist/Song.mp3
     *   or the live mtp:// root + relative path.
     *
     * Native libmtp holds exclusive access, so we release the session so
     * GVFS can mount, then play through the mount (no download).
     */
    private string? resolve_gvfs_uri (Media media) {
        AndroidDevice? android = find_device_for_uri (media.uri);
        if (android == null) {
            warning ("[MTP streamer] No AndroidDevice for %s", media.uri);
            return null;
        }

        /* relative path after mtp-native://SERIAL/ */
        string relative = relative_path_from_uri (media.uri, android.get_serial_number ());
        if (relative == null || relative.length == 0) {
            return null;
        }

        /* Free the USB device so GVFS/mtpfs can mount it. */
        android.release_mtp_for_playback ();

        /* Prefer an already-present mount (or one that appears shortly). */
        Mount? mount = android.get_mount ();
        if (mount == null) {
            mount = find_mtp_mount (android);
        }

        if (mount != null) {
            /* Same formula as iPodStreamer */
            string gvfs = "%s/.gvfs/%s/%s".printf (
                File.new_for_path (Environment.get_home_dir ()).get_uri (),
                mount.get_name (),
                relative
            );
            var gvfs_file = File.new_for_uri (gvfs);
            if (gvfs_file.query_exists ()) {
                print ("[MTP streamer] Playing via .gvfs: %s\n", gvfs);
                return gvfs;
            }

            /* Fallback: mtp:// (or whatever the mount root is) + relative */
            string root = mount.get_default_location ().get_uri ();
            if (!root.has_suffix ("/")) {
                root += "/";
            }
            string mtp_uri = root + relative;
            print ("[MTP streamer] Playing via mount root: %s\n", mtp_uri);
            return mtp_uri;
        }

        warning ("[MTP streamer] No GVFS/MTP mount available after releasing native session");
        return null;
    }

    private static string? relative_path_from_uri (string uri, string serial) {
        string prefix = "mtp-native://%s/".printf (serial);
        if (!uri.has_prefix (prefix)) {
            /* try without requiring exact serial match */
            int idx = uri.index_of ("/", "mtp-native://".length);
            if (idx < 0) {
                return null;
            }
            return uri.substring (idx + 1);
        }
        return uri.substring (prefix.length);
    }

    private AndroidDevice? find_device_for_uri (string uri) {
        var dm = DeviceManager.get_default ();
        foreach (var d in dm.get_initialized_devices ()) {
            if (d is AndroidDevice) {
                var a = (AndroidDevice) d;
                if (uri.has_prefix ("mtp-native://%s".printf (a.get_serial_number ()))) {
                    return a;
                }
            }
        }
        /* last resort: any Android device */
        foreach (var d in dm.get_initialized_devices ()) {
            if (d is AndroidDevice) {
                return (AndroidDevice) d;
            }
        }
        return null;
    }

    private Mount? find_mtp_mount (AndroidDevice android) {
        var monitor = VolumeMonitor.get ();
        string label = android.get_display_name ().down ();

        for (int attempt = 0; attempt < 15; attempt++) {
            foreach (var mount in monitor.get_mounts ()) {
                var root = mount.get_default_location ();
                if (root == null) {
                    continue;
                }
                var u = root.get_uri () ?? "";
                if (!u.has_prefix ("mtp://") && !u.has_prefix ("gphoto2://")) {
                    continue;
                }
                /* Prefer a mount whose name matches the device label */
                var name = (mount.get_name () ?? "").down ();
                if (label.length > 0 && (name.contains (label) || label.contains (name))) {
                    android.set_mount (mount);
                    return mount;
                }
                /* Otherwise take the first MTP mount */
                android.set_mount (mount);
                return mount;
            }
            Thread.usleep (200000); /* 200 ms — wait for GVFS to claim the device */
        }
        return null;
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
