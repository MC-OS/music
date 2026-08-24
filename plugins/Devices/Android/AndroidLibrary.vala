// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Scan audio + media folders for StorageBar categories; playlist is audio-only. */

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

    private bool is_tracked_extension (string name_down) {
        return name_down.has_suffix (".mp3") || name_down.has_suffix (".flac")
            || name_down.has_suffix (".m4a") || name_down.has_suffix (".ogg")
            || name_down.has_suffix (".wav") || name_down.has_suffix (".aac")
            || name_down.has_suffix (".opus") || name_down.has_suffix (".wma")
            || name_down.has_suffix (".mp4") || name_down.has_suffix (".mkv")
            || name_down.has_suffix (".avi") || name_down.has_suffix (".mov")
            || name_down.has_suffix (".webm") || name_down.has_suffix (".3gp")
            || name_down.has_suffix (".m4v") || name_down.has_suffix (".jpg")
            || name_down.has_suffix (".jpeg") || name_down.has_suffix (".png")
            || name_down.has_suffix (".gif") || name_down.has_suffix (".webp")
            || name_down.has_suffix (".heic") || name_down.has_suffix (".apk");
    }

    private bool is_audio_extension (string name_down) {
        return name_down.has_suffix (".mp3") || name_down.has_suffix (".flac")
            || name_down.has_suffix (".m4a") || name_down.has_suffix (".ogg")
            || name_down.has_suffix (".wav") || name_down.has_suffix (".aac")
            || name_down.has_suffix (".opus") || name_down.has_suffix (".wma")
            || name_down.has_suffix (".aiff");
    }

    private void collect_files (File dir, Gee.LinkedList<string> files, int depth) {
        if (operation_cancelled || depth > 8) {
            return;
        }

        try {
            var enumerator = dir.enumerate_children (
                "standard::name,standard::type",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                null
            );

            FileInfo? info;
            while ((info = enumerator.next_file (null)) != null) {
                if (operation_cancelled) {
                    break;
                }

                var child = dir.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    collect_files (child, files, depth + 1);
                } else if (info.get_file_type () == FileType.REGULAR) {
                    var name = info.get_name ().down ();
                    if (is_tracked_extension (name)) {
                        files.add (child.get_uri ());
                    }
                }
            }
        } catch (Error e) {
            debug ("collect_files %s: %s", dir.get_uri (), e.message);
        }
    }

    public async void finish_initialization_async () {
        var root = device.get_uri ();

        string[] candidates = {
            root + "/Music",
            root + "/music",
            root + "/Download",
            root + "/Downloads",
            root + "/Movies",
            root + "/Videos",
            root + "/DCIM",
            root + "/Pictures",
            root + "/Photo",
            root + "/Photos"
        };

        var folders = new Gee.LinkedList<string> ();
        foreach (var folder in candidates) {
            if (File.new_for_uri (folder).query_exists ()) {
                folders.add (folder);
            }
        }

        if (folders.size == 0) {
            folders.add (root);
        }

        var files = new Gee.LinkedList<string> ();
        foreach (var folder in folders) {
            collect_files (File.new_for_uri (folder), files, 0);
        }

        // Also pick up APKs under Android/data is too huge — only top-level Download
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
            file_operations_done ();
            return false;
        });
    }

    public override void add_files_to_library (Gee.Collection<string> files) {
    }

    public override void search_medias (string search) {
        lock (searched_medias) {
            searched_medias.clear ();

            // Device song list: audio only (videos/photos still counted for the bar)
            foreach (var m in medias.values) {
                var uri = (m.uri ?? "").down ();
                if (!is_audio_extension (uri)) {
                    continue;
                }

                if (search == null || search == "") {
                    searched_medias.add (m);
                } else {
                    uint parsed_rating;
                    string parsed_search_string;
                    String.base_search_method (search, out parsed_rating, out parsed_search_string);
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
