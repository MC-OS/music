// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Experimental: stream the MTP object straight into GStreamer.
 *
 * libmtp writes the object into a pipe (Get_File_To_File_Descriptor).
 * GStreamer reads the other end via fd:// — no temp file, no GVFS.
 *
 * This may fail on some GStreamer builds (fd:// support) or if the
 * decoder needs seekable input. That is the experiment.
 */

public class Music.Plugins.AndroidStreamer : Music.Playback, GLib.Object {
    Music.Pipeline pipe;
    InstallGstreamerPluginsDialog dialog;
    public bool set_resume_pos;

    private AndroidDeviceManager manager;
    private int stream_read_fd = -1;

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
        close_stream_fd ();

        string? fd_uri = open_device_stream (media);
        if (fd_uri == null) {
            warning ("[MTP streamer] Could not open device stream for %s", media.uri);
            error_occured ();
            return;
        }

        print ("[MTP streamer] Streaming via %s\n", fd_uri);
        pipe.playbin.set_property ("uri", fd_uri);
        set_state (Gst.State.PLAYING);
        /* Seek is best-effort — fd streams are often not seekable */
        pipe.playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, (int64)App.player.current_media.resume_pos * 1000000000);
        play ();
    }

    /*
     * Create a pipe. A worker thread pumps the MTP object into the write
     * end; we hand GStreamer the read end as fd://N.
     */
    private string? open_device_stream (Media media) {
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

        unowned Mtp.Device? mtp = lib.get_mtp ();
        if (mtp == null) {
            warning ("[MTP streamer] MTP session is gone");
            return null;
        }

        int[] fds = new int[2];
        if (Posix.pipe (fds) != 0) {
            warning ("[MTP streamer] pipe() failed");
            return null;
        }
        int read_fd = fds[0];
        int write_fd = fds[1];

        /* Capture for the worker thread (mtp is unowned — session must stay alive). */
        unowned Mtp.Device device = mtp;
        uint32 id = item_id;

        new Thread<void*> ("mtp-fd-stream", () => {
            print ("[MTP streamer] Worker: streaming object %u into fd %d\n", id, write_fd);
            int ret = device.get_file_to_file_descriptor (id, write_fd, null, null);
            if (ret != 0) {
                warning ("[MTP streamer] Get_File_To_File_Descriptor failed (%d)", ret);
            } else {
                print ("[MTP streamer] Worker: finished object %u\n", id);
            }
            Posix.close (write_fd);
            return null;
        });

        stream_read_fd = read_fd;
        return "fd://%d".printf (read_fd);
    }

    private void close_stream_fd () {
        if (stream_read_fd >= 0) {
            Posix.close (stream_read_fd);
            stream_read_fd = -1;
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
                close_stream_fd ();
                end_of_stream ();
                break;
            default:
                break;
        }
        return true;
    }
}
