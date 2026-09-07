// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Holds the tracks from an audio CD.
 *
 * Lazy: only reads the TOC when the user opens the CD.
 * Uses cdparanoiasrc to get the real track count, then creates
 * simple "Track N" placeholders. No durations or tags until import.
 */

public class Music.Plugins.CDLibrary : Music.Library {
    private Gee.HashMap<string, Music.Media> medias;
    private Gee.LinkedList<Music.Media> searched_medias;
    private CDDevice device;
    private bool is_doing_file_operations = false;
    private bool scan_started = false;
    private uint next_rowid = 1;

    public CDLibrary (CDDevice device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();
    }

    public override void initialize_library () {
    }

    /* Lightweight – device is ready, no drive access yet.
     * Emit initialized on Idle so CDDeviceManager can connect first. */
    public async void finish_initialization_async () {
        Idle.add (() => {
            device.initialized (device);
            return false;
        });
    }

    /* Called the first time the user opens the CD view. */
    public void ensure_scanned () {
        if (scan_started) {
            return;
        }
        scan_started = true;
        message ("[CD] starting lazy TOC scan");
        start_scan.begin ();
    }

    private async void start_scan () {
        is_doing_file_operations = true;
        file_operations_started ();

        yield read_toc ();

        is_doing_file_operations = false;
        file_operations_done ();
        search_medias ("");
    }

    private async void read_toc () {
        string? device_path = device.get_volume ().get_identifier ("unix-device");
        message ("[CD] reading TOC, device = %s", device_path ?? "(default)");

        uint track_count = 0;

        SourceFunc callback = read_toc.callback;

        new Thread<void*> ("cd-toc", () => {
            track_count = query_track_count (device_path);
            Idle.add ((owned) callback);
            return null;
        });

        yield;

        if (track_count == 0) {
            warning ("[CD] no audio tracks found");
            return;
        }

        message ("[CD] TOC reports %u tracks", track_count);

        for (uint t = 1; t <= track_count; t++) {
            add_placeholder_track (t, track_count);
        }
    }

    private static uint query_track_count (string? device_path) {
        Gst.Element? src = Gst.ElementFactory.make ("cdparanoiasrc", "cdsrc");
        if (src == null) {
            src = Gst.ElementFactory.make ("cdiocddasrc", "cdsrc");
        }
        if (src == null) {
            warning ("[CD] neither cdparanoiasrc nor cdiocddasrc is available");
            return 0;
        }

        if (device_path != null) {
            src.set ("device", device_path);
        }

        var pipeline = new Gst.Pipeline ("cd-toc-pipeline");
        var sink = Gst.ElementFactory.make ("fakesink", "sink");
        pipeline.add_many (src, sink);
        src.link (sink);

        var ret = pipeline.set_state (Gst.State.PAUSED);
        if (ret == Gst.StateChangeReturn.FAILURE) {
            warning ("[CD] failed to pause cd source");
            pipeline.set_state (Gst.State.NULL);
            return 0;
        }

        Gst.State state;
        pipeline.get_state (out state, null, 5 * Gst.SECOND);

        uint count = 0;
        var format = Gst.Format.get_by_nick ("track");
        if (format != Gst.Format.UNDEFINED) {
            int64 duration = 0;
            if (pipeline.query_duration (format, out duration) && duration > 0) {
                count = (uint) duration;
            }
        }

        pipeline.set_state (Gst.State.NULL);
        return count;
    }

    private void add_placeholder_track (uint track, uint total) {
        string uri = "cdda://%u".printf (track);

        lock (medias) {
            if (medias.has_key (uri)) {
                return;
            }
        }

        var media = new Music.Media (uri);
        media.rowid = next_rowid++;
        media.track = track;
        media.track_count = total;
        media.title = _("Track %u").printf (track);
        media.artist = _("Unknown");
        media.album = device.get_display_name ();
        media.is_temporary = true;
        media.file_size = 0;

        lock (medias) {
            medias.set (uri, media);
        }

        var added = new Gee.ArrayList<Music.Media> ();
        added.add (media);
        media_added (added);
    }

    public override void add_files_to_library (Gee.Collection<string> files) {
    }

    public override void add_medias (Gee.Collection<Music.Media> list) {
    }

    public override void search_medias (string search) {
        /* Do not call ensure_scanned here – scanning is triggered by the view */
        lock (searched_medias) {
            searched_medias.clear ();
            if (search == null || search == "") {
                searched_medias.add_all (medias.values);
            } else {
                foreach (var m in medias.values) {
                    if (Search.match_string_to_media (m, search)) {
                        searched_medias.add (m);
                    }
                }
            }
        }
        search_finished ();
    }

    public override Gee.Collection<Media> get_search_result () {
        return searched_medias;
    }

    public override Gee.Collection<Media> get_medias () {
        return medias.values;
    }

    public override Gee.Collection<StaticPlaylist> get_playlists () {
        return new Gee.LinkedList<StaticPlaylist> ();
    }

    public override Gee.Collection<SmartPlaylist> get_smart_playlists () {
        return new Gee.LinkedList<SmartPlaylist> ();
    }

    public override void add_media (Music.Media s) {}
    public override Media? media_from_id (int64 id) { return null; }
    public override Gee.Collection<Media> medias_from_ids (Gee.Collection<int64?> ids) {
        return new Gee.LinkedList<Media> ();
    }

    public override Gee.Collection<Media> medias_from_uris (Gee.Collection<string> uris) {
        var result = new Gee.LinkedList<Media> ();
        lock (medias) {
            foreach (var m in medias.values) {
                if (uris.contains (m.uri)) {
                    result.add (m);
                }
            }
        }
        return result;
    }

    public override Media? find_media (Media to_find) { return null; }
    public override Media? media_from_file (File file) { return media_from_uri (file.get_uri ()); }

    public override Media? media_from_uri (string uri) {
        lock (medias) {
            return medias.has_key (uri) ? medias.get (uri) : null;
        }
    }

    public override void update_media (Media s, bool update_meta, bool record_time) {}
    public override void update_medias (Gee.Collection<Media> updates, bool update_meta, bool record_time) {}
    public override void remove_media (Media s, bool trash) {}
    public override void remove_medias (Gee.Collection<Music.Media> to_remove, bool trash) {}

    public override void add_smart_playlist (SmartPlaylist p) {}
    public override bool support_smart_playlists () { return false; }
    public override void remove_smart_playlist (int64 id) {}
    public override SmartPlaylist? smart_playlist_from_id (int64 id) { return null; }
    public override SmartPlaylist? smart_playlist_from_name (string name) { return null; }

    public override bool support_playlists () { return false; }
    public override void add_playlist (StaticPlaylist p) {}
    public override void remove_playlist (int64 id) {}
    public override StaticPlaylist? playlist_from_id (int64 id) { return null; }
    public override StaticPlaylist? playlist_from_name (string name) { return null; }

    public override bool start_file_operations (string? message) { return true; }
    public override bool doing_file_operations () { return is_doing_file_operations; }
    public override void finish_file_operations () {}
}
