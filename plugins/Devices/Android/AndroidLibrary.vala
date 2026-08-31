// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Native MTP library: lists audio under the device Music folder. */

public class Music.Plugins.AndroidLibrary : Music.Library {
    Gee.HashMap<string, Music.Media> medias;
    Gee.LinkedList<Music.Media> searched_medias;
    AndroidDevice device;

    private unowned Mtp.Device? mtp;
    private uint32 storage_id = 0;
    private bool operation_cancelled = false;
    private bool is_doing_file_operations = false;

    private const string MUSIC_FOLDER = "Music";

    public AndroidLibrary (AndroidDevice device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();

        mtp = device.get_mtp_device ();
        storage_id = device.get_internal_storage_id ();

        NotificationManager.get_default ().progress_canceled.connect (() => {
            operation_cancelled = true;
        });
    }

    public override void initialize_library () {
    }

    public async void finish_initialization_async () {
        yield scan_music_async ();

        Idle.add (() => {
            device.initialized (device);
            search_medias ("");
            file_operations_done ();
            return false;
        });
    }

    private async void scan_music_async () {
        if (mtp == null || storage_id == 0) {
            print ("[MTP library] No MTP session or storage id — skipping Music scan\n");
            return;
        }

        is_doing_file_operations = true;
        operation_cancelled = false;
        libraries_manager.current_operation = _("Reading <b>%s</b>…").printf (device.get_display_name ());

        yield scan_folder_async (MUSIC_FOLDER);

        is_doing_file_operations = false;
        print ("[MTP library] Found %d audio file(s) in Music on %s\n", medias.size, device.get_display_name ());
    }

    /* Find top-level folder by name (case-insensitive) and recurse into it. */
    private async void scan_folder_async (string folder_name) {
        unowned Mtp.File? root = mtp.get_files_and_folders (storage_id, Mtp.FILES_AND_FOLDERS_ROOT);
        if (root == null) {
            return;
        }

        uint32 target_id = 0;
        unowned Mtp.File? file = root;
        while (file != null) {
            if (file.filetype == Mtp.Filetype.FOLDER
                && file.filename != null
                && file.filename.down () == folder_name.down ()) {
                target_id = file.item_id;
                unowned Mtp.File? next = file.next;
                Mtp.destroy_file_t (file);
                file = next;
                break;
            }
            unowned Mtp.File? next = file.next;
            Mtp.destroy_file_t (file);
            file = next;
        }

        /* free remaining root entries */
        while (file != null) {
            unowned Mtp.File? next = file.next;
            Mtp.destroy_file_t (file);
            file = next;
        }

        if (target_id == 0) {
            print ("[MTP library] Folder '%s' not found on device\n", folder_name);
            return;
        }

        yield recurse_async (target_id, folder_name);
    }

    private async void recurse_async (uint32 parent_id, string relative_path) {
        unowned Mtp.File? file = mtp.get_files_and_folders (storage_id, parent_id);
        if (file == null) {
            return;
        }

        while (file != null) {
            if (operation_cancelled) {
                Mtp.destroy_file_t (file);
                break;
            }

            string name = file.filename ?? "";
            string child_path = relative_path + "/" + name;

            if (file.filetype == Mtp.Filetype.FOLDER) {
                uint32 child_id = file.item_id;
                unowned Mtp.File? next = file.next;
                Mtp.destroy_file_t (file);
                file = next;
                yield recurse_async (child_id, child_path);
                continue;
            }

            if (Mtp.filetype_is_audio (file.filetype)) {
                var media = media_from_mtp_file (file, child_path);
                if (media != null && !medias.has_key (media.uri)) {
                    medias.set (media.uri, media);
                }
            }

            unowned Mtp.File? next = file.next;
            Mtp.destroy_file_t (file);
            file = next;
        }
    }

    private Music.Media? media_from_mtp_file (unowned Mtp.File file, string relative_path) {
        if (file.filename == null) {
            return null;
        }

        string uri = "mtp-native://%s/%s".printf (device.get_serial_number (), relative_path);
        var media = new Music.Media (uri);
        media.file_size = file.filesize;
        media.last_modified = (uint) file.modificationdate;

        /* Copy the libmtp-owned string before string methods.
         * Do NOT name this variable "base" — that is a Vala keyword for the parent class. */
        string basename = file.filename;
        int dot = basename.last_index_of_char ('.');
        if (dot > 0) {
            basename = basename.substring (0, dot);
        }
        media.title = basename;

        return media;
    }

    public override void add_files_to_library (Gee.Collection<string> files) {
    }

    public override void search_medias (string search) {
        lock (searched_medias) {
            searched_medias.clear ();

            if (search == "" || search == null) {
                searched_medias.add_all (medias.values);
                search_finished ();
                return;
            }

            uint parsed_rating;
            string parsed_search_string;
            String.base_search_method (search, out parsed_rating, out parsed_search_string);
            bool rating_search = parsed_rating > 0;

            lock (medias) {
                foreach (var m in medias.values) {
                    if (rating_search) {
                        if (m.rating == parsed_rating) {
                            searched_medias.add (m);
                        }
                    } else if (Search.match_string_to_media (m, parsed_search_string)) {
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
        var media_collection = new Gee.LinkedList<Media> ();
        lock (medias) {
            foreach (var m in medias.values) {
                if (uris.contains (m.uri)) {
                    media_collection.add (m);
                }
                if (media_collection.size == uris.size) {
                    break;
                }
            }
        }
        return media_collection;
    }

    public override Media? find_media (Media to_find) {
        Media? found = null;
        lock (medias) {
            foreach (var m in medias.values) {
                if (to_find.title.down () == m.title.down () && to_find.artist.down () == m.artist.down ()) {
                    found = m;
                    break;
                }
            }
        }
        return found;
    }

    public override Media? media_from_file (File file) {
        return media_from_uri (file.get_uri ());
    }

    public override Media? media_from_uri (string uri) {
        lock (medias) {
            if (medias.has_key (uri)) {
                return medias.get (uri);
            }
        }
        return null;
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
