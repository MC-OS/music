// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Holds the tracks from an audio CD. */

public class Music.Plugins.CDLibrary : Music.Library {
    private Gee.HashMap<string, Music.Media> medias;
    private Gee.LinkedList<Music.Media> searched_medias;
    private CDDevice device;
    private bool is_doing_file_operations = false;

    public CDLibrary (CDDevice device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();
    }

    public override void initialize_library () {
    }

    public async void finish_initialization_async () {
        /* TODO: read TOC and populate tracks */
        Idle.add (() => {
            device.initialized (device);
            search_medias ("");
            file_operations_done ();
            return false;
        });
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
