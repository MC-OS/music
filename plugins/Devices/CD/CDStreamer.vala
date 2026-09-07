// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Streamer for cdda:// URIs – playbin does the work. */

public class Music.Plugins.CDStreamer : Music.Playback, GLib.Object {
    Music.Pipeline pipe;
    public bool set_resume_pos;
    private CDDeviceManager manager;

    public CDStreamer (CDDeviceManager manager) {
        this.manager = manager;
        pipe = new Music.Pipeline ();
        pipe.bus.add_watch (GLib.Priority.DEFAULT, bus_callback);
        Timeout.add (200, update_position);
    }

    public Gee.Collection<string> get_supported_uri () {
        var uris = new Gee.LinkedList<string> ();
        uris.add ("cdda://");
        uris.add ("cd://");
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

    public void play () { set_state (Gst.State.PLAYING); }
    public void pause () { set_state (Gst.State.PAUSED); }

    public void set_state (Gst.State s) {
        pipe.playbin.set_state (s);
    }

    public void set_media (Media media) {
        set_state (Gst.State.READY);
        pipe.playbin.set_property ("uri", media.uri);
        set_state (Gst.State.PLAYING);
        pipe.playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH,
            (int64) App.player.current_media.resume_pos * 1000000000);
        play ();
    }

    public void set_position (int64 pos) {
        pipe.playbin.seek (1.0, Gst.Format.TIME, Gst.SeekFlags.FLUSH,
            Gst.SeekType.SET, pos, Gst.SeekType.NONE, get_duration ());
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

    public void enable_equalizer () { pipe.enable_equalizer (); }
    public void disable_equalizer () { pipe.disable_equalizer (); }
    public void set_equalizer_gain (int index, int val) { pipe.eq.set_gain (index, val); }

    private bool bus_callback (Gst.Bus bus, Gst.Message message) {
        switch (message.type) {
            case Gst.MessageType.ERROR:
                GLib.Error err;
                string debug_msg;
                message.parse_error (out err, out debug_msg);
                warning ("[CD streamer] %s", err.message);
                error_occured ();
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
