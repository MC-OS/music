// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Audio CD library via pure GVFS/GIO (cdda://).
 *
 * Eager scan: tracks are listed as soon as the library is created, matching
 * AudioPlayerLibrary so the DeviceViewWrapper has media when it builds.
 *
 * Import: tracks are is_temporary, so MediaMenu shows "Import to Library".
 * DeviceViewWrapper.import_request -> transfer_to_local_library, which
 * File.copies each cdda:// URI via GVFS into the music folder.
 */

public class Music.Plugins.CDLibrary : Music.Library {
    private Gee.HashMap<string, Music.Media> medias;
    private Gee.LinkedList<Music.Media> searched_medias;
    private CDDevice device;
    private bool is_doing_file_operations = false;
    private bool scan_started = false;
    private uint next_rowid = 1;

    /* Red Book: 2352 bytes/sector, 75 sectors/second. */
    private const uint BYTES_PER_SECTOR = 2352;
    private const uint SECTORS_PER_SEC = 75;

    public CDLibrary (CDDevice device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();
    }

    public override void initialize_library () {
    }

    public async void finish_initialization_async () {
        Idle.add (() => {
            device.initialized (device);
            return false;
        });

        // Eager scan so tracks exist before DeviceViewWrapper builds.
        ensure_scanned ();
    }

    public void ensure_scanned () {
        if (scan_started) {
            return;
        }
        scan_started = true;
        message ("[CD] starting GVFS track listing");
        start_scan.begin ();
    }

    private async void start_scan () {
        is_doing_file_operations = true;
        file_operations_started ();

        yield list_tracks_via_gvfs ();

        is_doing_file_operations = false;
        file_operations_done ();
        search_medias ("");
    }

    private string cdda_root_uri () {
        string? unix_device = device.get_volume ().get_identifier ("unix-device");
        if (unix_device != null && unix_device.has_prefix ("/dev/")) {
            string device_name = unix_device.substring (5);
            return "cdda://%s/".printf (device_name);
        }

        return "cdda://";
    }

    private async void list_tracks_via_gvfs () {
        string root = cdda_root_uri ();
        message ("[CD] enumerating %s", root);

        var file = File.new_for_uri (root);

        try {
            yield file.mount_enclosing_volume (MountMountFlags.NONE, null, null);
        } catch (Error e) {
            debug ("[CD] mount_enclosing_volume: %s", e.message);
        }

        try {
            var attrs = string.join (",",
                FileAttribute.STANDARD_NAME,
                FileAttribute.STANDARD_DISPLAY_NAME,
                "xattr::org.gnome.audio.title",
                "xattr::org.gnome.audio.artist",
                "xattr::org.gnome.audio.duration"
            );

            var enumerator = yield file.enumerate_children_async (
                attrs, FileQueryInfoFlags.NONE, Priority.DEFAULT, null);

            uint track = 0;
            while (true) {
                var infos = yield enumerator.next_files_async (20, Priority.DEFAULT, null);
                if (infos == null || infos.length () == 0) {
                    break;
                }

                foreach (var info in infos) {
                    track++;
                    string name = info.get_name ();
                    string child_uri = file.get_child (name).get_uri ();

                    string title = info.get_attribute_string ("xattr::org.gnome.audio.title");
                    if (title == null || title == "") {
                        title = info.get_display_name () ?? _("Track %u").printf (track);
                        if (title.has_suffix (".wav")) {
                            title = title.substring (0, title.length - 4);
                        }
                    }

                    string? artist = info.get_attribute_string ("xattr::org.gnome.audio.artist");
                    uint64 duration_sec = info.get_attribute_uint64 ("xattr::org.gnome.audio.duration");

                    add_track (track, child_uri, title, artist, duration_sec);
                    message ("[CD] track %u: %s", track, title);
                }
            }

            message ("[CD] GVFS listed %u tracks", medias.size);
        } catch (Error e) {
            warning ("[CD] GVFS enumerate failed: %s", e.message);
        }
    }

    private void add_track (uint track, string uri, string title, string? artist, uint64 duration_sec) {
        lock (medias) {
            if (medias.has_key (uri)) {
                return;
            }
        }

        var media = new Music.Media (uri);
        media.rowid = next_rowid++;
        media.track = track;
        media.track_count = (uint) medias.size + 1;
        media.title = title;
        media.artist = (artist != null && artist != "") ? artist : _("Unknown");
        media.album = device.get_display_name ();
        media.is_temporary = true;

        /* Default ~4 min if duration missing so storage bar still has a slice. */
        double secs = duration_sec > 0 ? (double) duration_sec : 240.0;
        media.length = (uint) (secs * 1000);
        media.file_size = (uint64) (secs * SECTORS_PER_SEC * BYTES_PER_SECTOR);

        lock (medias) {
            medias.set (uri, media);
        }

        var added = new Gee.ArrayList<Media> ();
        added.add (media);
        media_added (added);
    }

    public override void add_files_to_library (Gee.Collection<string> files) {}
    public override void add_medias (Gee.Collection<Music.Media> list) {}

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

    public override Gee.Collection<Media> get_search_result () { return searched_medias; }
    public override Gee.Collection<Media> get_medias () { return medias.values; }
    public override Gee.Collection<StaticPlaylist> get_playlists () { return new Gee.LinkedList<StaticPlaylist> (); }
    public override Gee.Collection<SmartPlaylist> get_smart_playlists () { return new Gee.LinkedList<SmartPlaylist> (); }

    public override void add_media (Music.Media s) {}
    public override Media? media_from_id (int64 id) { return null; }
    public override Gee.Collection<Media> medias_from_ids (Gee.Collection<int64?> ids) { return new Gee.LinkedList<Media> (); }

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
