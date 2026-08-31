// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Playback for mtp-native:// — pull the object with libmtp into a temp
 * file, then hand a file:// URI to GStreamer (same idea as Amarok MTP).
 */

public class Music.Plugins.AndroidStreamer : Music.Playback, GLib.Object {
    Music.Pipeline pipe;
    InstallGstreamerPluginsDialog dialog;
    public bool set_resume_pos;

    private AndroidDeviceManager manager;
    private string? temp_path = null;

    public AndroidStreamer (AndroidDeviceManager manager) {
        this.manager = manager;
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
        cleanup_temp ();

        string? local_uri = download_to_temp (media);
        if (local_uri == null) {
            warning ("[MTP streamer] Download failed for %s", media.uri);
            error_occured ();
            return;
        }

        debug ("[MTP streamer] set uri to %s\n", local_uri);
        pipe.playbin.set_property ("uri", local_uri);
        set_state (Gst.State.PLAYING);
        pipe.playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, (int64)App.player.current_media.resume_pos * 1000000000);
        play ();
    }

    private string? download_to_temp (Media media) {
        var android = manager.get_device_for_uri (media.uri);
        if (android == null) {
            warning ("[MTP streamer] No device for %s", media.uri);
            return null;
        }

        var lib = android.get_library () as AndroidLibrary;
        if (lib == null) {
            warning ("[MTP streamer] No AndroidLibrary");
            return null;
        }

        uint32 item_id = lib.get_item_id (media.uri);
        if (item_id == 0) {
            warning ("[MTP streamer] No item_id for %s", media.uri);
            return null;
        }

        unowned Mtp.Device? mtp = lib.get_mtp ();
        if (mtp == null) {
            warning ("[MTP streamer] MTP session is gone");
            return null;
        }

        string ext = ".bin";
        int dot = media.uri.last_index_of_char ('.');
        if (dot > 0 && media.uri.length - dot <= 5) {
            ext = media.uri.substring (dot);
        }

        string name_used;
        try {
            /* Vala: File.new_tmp (tmpl, out string name_used) */
            File.new_tmp ("music-mtp-XXXXXX" + ext, out name_used);
            temp_path = name_used;
        } catch (Error e) {
            warning ("[MTP streamer] temp file: %s", e.message);
            return null;
        }

        print ("[MTP streamer] Downloading item %u → %s\n", item_id, temp_path);
        int ret = mtp.get_file_to_file (item_id, temp_path);
        if (ret != 0) {
            warning ("[MTP streamer] Get_File_To_File failed (%d)", ret);
            cleanup_temp ();
            return null;
        }

        return File.new_for_path (temp_path).get_uri ();
    }

    private void cleanup_temp () {
        if (temp_path != null) {
            try {
                File.new_for_path (temp_path).delete ();
            } catch (Error e) {
            }
            temp_path = null;
        }
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
                cleanup_temp ();
                end_of_stream ();
                break;
            default:
                break;
        }
        return true;
    }
}
