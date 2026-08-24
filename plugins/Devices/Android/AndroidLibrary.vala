// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Chunk 1: minimal library — list music files + file_size for later bar/playback. */

public class Music.Plugins.AndroidLibrary : Music.Library {
    Gee.HashMap<string, Music.Media> medias;
    Gee.LinkedList<Music.Media> searched_medias;
    Device device;
    bool operation_cancelled = false;
    bool is_doing_file_operations = false;

    public AndroidLibrary (Device device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();

        NotificationManager.get_default ().progress_canceled.connect (() => {
            operation_cancelled = true;
        });
    }

    public override void initialize_library () {
    }

    private uint64 query_file_size (string file_uri) {
        try {
            var info = File.new_for_uri (file_uri).query_info (
                FileAttribute.STANDARD_SIZE,
                FileQueryInfoFlags.NONE,
                null
            );
            return info.get_size ();
        } catch (Error e) {
            return 0;
        }
    }

    public async void finish_initialization_async () {
        var root = device.get_uri ();
        var music_folders = new Gee.LinkedList<string> ();

        string[] candidates = {
            root + "/Music",
            root + "/music",
            root + "/Download",
            root + "/Downloads"
        };

        foreach (var folder in candidates) {
            if (File.new_for_uri (folder).query_exists ()) {
                music_folders.add (folder);
            }
        }

        if (music_folders.size == 0) {
            music_folders.add (root);
        }

        var files = new Gee.LinkedList<string> ();
        foreach (var folder in music_folders) {
            FileUtils.count_music_files (File.new_for_uri (folder), files);
        }

        foreach (var file_uri in files) {
            if (operation_cancelled) {
                break;
            }

            if (!medias.has_key (file_uri)) {
                var media = new Music.Media (file_uri);
                media.is_temporary = true;
                media.file_size = query_file_size (file_uri);
                medias.set (file_uri, media);
            }
        }

        Idle.add (() => {
            if (device is AndroidDevice) {
                ((AndroidDevice) device).notify_name_ready ();
            }

            device.initialized (device);
            search_medias ("");
            return false;
        });
    }

    public override void add_files_to_library (Gee.Collection<string> files) {
    }

    public override void search_medias (string search) {
        lock (searched_medias) {
            searched_medias.clear ();
            if (search == null || search == "") {
                searched_medias.add_all (medias.values);
            } else {
                uint parsed_rating;
                string parsed_search_string;
                String.base_search_method (search, out parsed_rating, out parsed_search_string);
                foreach (var m in medias.values) {
                    if (Search.match_string_to_media (m, parsed_search_string)) {
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

    public override void add_media (Music.Media s) {
    }

    public override void add_medias (Gee.Collection<Music.Media> list) {
    }

    public override Media? media_from_id (int64 id) {
        return null;
    }

    public override Gee.Collection<Media> medias_from_ids (Gee.Collection<int64?> ids) {
        return new Gee.LinkedList<Media> ();
    }

    public override Gee.Collection<Media> medias_from_uris (Gee.Collection<string> uris) {
        var out_list = new Gee.LinkedList<Media> ();
        foreach (var uri in uris) {
            if (medias.has_key (uri)) {
                out_list.add (medias.get (uri));
            }
        }
        return out_list;
    }

    public override Media? find_media (Media to_find) {
        return null;
    }

    public override Media? media_from_file (File file) {
        return media_from_uri (file.get_uri ());
    }

    public override Media? media_from_uri (string uri) {
        return medias.has_key (uri) ? medias.get (uri) : null;
    }

    public override void update_media (Media s, bool update_meta, bool record_time) {
    }

    public override void update_medias (Gee.Collection<Media> updates, bool update_meta, bool record_time) {
    }

    public override void remove_media (Media s, bool trash) {
    }

    public override void remove_medias (Gee.Collection<Music.Media> to_remove, bool trash) {
    }

    public override void add_smart_playlist (SmartPlaylist p) {
    }

    public override bool support_smart_playlists () {
        return false;
    }

    public override void remove_smart_playlist (int64 id) {
    }

    public override SmartPlaylist? smart_playlist_from_id (int64 id) {
        return null;
    }

    public override SmartPlaylist? smart_playlist_from_name (string name) {
        return null;
    }

    public override bool support_playlists () {
        return false;
    }

    public override void add_playlist (StaticPlaylist p) {
    }

    public override void remove_playlist (int64 id) {
    }

    public override StaticPlaylist? playlist_from_id (int64 id) {
        return null;
    }

    public override StaticPlaylist? playlist_from_name (string name) {
        return null;
    }

    public override bool start_file_operations (string? message) {
        return true;
    }

    public override bool doing_file_operations () {
        return is_doing_file_operations;
    }

    public override void finish_file_operations () {
    }
}
