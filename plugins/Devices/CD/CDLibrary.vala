// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Holds the tracks from an audio CD.
 *
 * Discovers each track individually (cdda://1, cdda://2, ...) because
 * handing a bare cdda:// or device node to Discoverer almost never
 * returns useful per-track streams.
 */

public class Music.Plugins.CDLibrary : Music.Library {
    private Gee.HashMap<string, Music.Media> medias;
    private Gee.LinkedList<Music.Media> searched_medias;
    private CDDevice device;
    private bool is_doing_file_operations = false;
    private uint next_rowid = 1;

    public CDLibrary (CDDevice device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();
    }

    public override void initialize_library () {
    }

    public async void finish_initialization_async () {
        is_doing_file_operations = true;
        file_operations_started ();

        yield read_disc_toc ();

        is_doing_file_operations = false;
        file_operations_done ();
        device.initialized (device);
        search_medias ("");
    }

    private async void read_disc_toc () {
        string? device_path = device.get_volume ().get_identifier ("unix-device");
        string? cdda_id = device.get_volume ().get_identifier ("cdda");

        message ("[CD] unix-device = %s", device_path ?? "(null)");
        message ("[CD] cdda identifier = %s", cdda_id ?? "(null)");

        /* Build the base form that GStreamer cdparanoiasrc understands.
         * Prefer the classic cdda://N form; fall back to device-qualified. */
        string track_uri_template;
        if (device_path != null && device_path.has_prefix ("/dev/")) {
            track_uri_template = "cdda://%u#" + device_path;
        } else {
            track_uri_template = "cdda://%u";
        }

        message ("[CD] probing tracks with template: %s", track_uri_template);

        Gst.PbUtils.Discoverer discoverer;
        try {
            discoverer = new Gst.PbUtils.Discoverer (8 * Gst.SECOND);
        } catch (Error e) {
            warning ("[CD] could not create Discoverer: %s", e.message);
            return;
        }

        /* Probe sequential tracks until we hit a failure.
         * Real audio CDs are almost never > 30 tracks; hard stop at 99. */
        for (uint track = 1; track <= 99; track++) {
            string uri = track_uri_template.printf (track);
            Gst.PbUtils.DiscovererInfo? info = null;

            try {
                info = discoverer.discover_uri (uri);
            } catch (Error e) {
                message ("[CD] track %u failed: %s", track, e.message);
                break;
            }

            if (info == null) {
                message ("[CD] track %u returned null info", track);
                break;
            }

            var result = info.get_result ();
            if (result != Gst.PbUtils.DiscovererResult.OK &&
                result != Gst.PbUtils.DiscovererResult.TIMEOUT) {
                message ("[CD] track %u result = %s — stopping", track, result.to_string ());
                break;
            }

            Gst.ClockTime duration = info.get_duration ();
            Gst.TagList? tags = info.get_tags ();

            message ("[CD] found track %u  duration=%" + int64.FORMAT + " ns", track, (int64) duration);
            add_track (track, duration, tags);
        }

        message ("[CD] finished probing — %u tracks in library", medias.size);
    }

    private void add_track (uint track, Gst.ClockTime duration, Gst.TagList? tags) {
        string uri = "cdda://%u".printf (track);
        var media = new Music.Media (uri);
        media.rowid = next_rowid++;
        media.track = track;
        media.track_count = (uint) medias.size + 1;
        media.title = _("Track %u").printf (track);
        media.artist = _("Unknown");
        media.album = device.get_display_name ();
        media.is_temporary = true;
        media.file_size = 0;

        if (duration != Gst.CLOCK_TIME_NONE && duration > 0) {
            media.length = (uint) (duration / Gst.MSECOND);
        }

        if (tags != null) {
            string? title = null, artist = null, album = null, genre = null;
            tags.get_string (Gst.Tags.TITLE, out title);
            tags.get_string (Gst.Tags.ARTIST, out artist);
            tags.get_string (Gst.Tags.ALBUM, out album);
            tags.get_string (Gst.Tags.GENRE, out genre);
            if (title != null && title != "") {
                media.title = title;
            }
            if (artist != null && artist != "") {
                media.artist = artist;
            }
            if (album != null && album != "") {
                media.album = album;
            }
            if (genre != null) {
                media.genre = genre;
            }
        }

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
        /* Import will go here */
    }

    public override void search_medias (string search) {
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
