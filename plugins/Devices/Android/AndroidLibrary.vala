// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Import a track from the Android MTP device into the local Music library. */

public class Music.Plugins.AndroidLibrary : Music.Library {
    Gee.HashMap<string, Music.Media> medias;
    Gee.LinkedList<Music.Media> searched_medias;
    /* uri → MTP object id (needed to download for playback / import) */
    Gee.HashMap<string, uint32> item_ids;
    AndroidDevice device;

    private unowned Mtp.Device? mtp;
    private uint32 storage_id = 0;
    private bool operation_cancelled = false;
    private bool is_doing_file_operations = false;

    private const string MUSIC_FOLDER = "Music";

    /* Context passed to the libmtp progress callback. */
    private class TransferContext {
        public int index;
        public int total;
        public unowned AndroidLibrary library;
    }

    public AndroidLibrary (AndroidDevice device) {
        this.device = device;
        medias = new Gee.HashMap<string, Music.Media> ();
        searched_medias = new Gee.LinkedList<Music.Media> ();
        item_ids = new Gee.HashMap<string, uint32> ();

        mtp = device.get_mtp_device ();
        storage_id = device.get_internal_storage_id ();

        NotificationManager.get_default ().progress_canceled.connect (() => {
            operation_cancelled = true;
        });
    }

    public uint32 get_item_id (string uri) {
        return item_ids.has_key (uri) ? item_ids.get (uri) : 0;
    }

    public unowned Mtp.Device? get_mtp () {
        return mtp;
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
                    item_ids.set (media.uri, file.item_id);
                }
            }

            unowned Mtp.File? next = file.next;
            Mtp.destroy_file_t (file);
            file = next;
        }
    }

    /*
     * Build a Media from the basic file listing, then enrich it with
     * LIBMTP_Get_Trackmetadata when available (title/artist/album/etc.).
     * Note: Track is owned by Vala (free_function on the Compact class);
     * do NOT call destroy_track_t manually or you get a double-free.
     */
    private Music.Media? media_from_mtp_file (unowned Mtp.File file, string relative_path) {
        if (file.filename == null) {
            return null;
        }

        string uri = "mtp-native://%s/%s".printf (device.get_serial_number (), relative_path);
        var media = new Music.Media (uri);
        media.file_size = file.filesize;
        media.last_modified = (uint) file.modificationdate;
        /* Device tracks are not in the local library yet — mark temporary so
         * MediaMenu enables "Import to Library". */
        media.is_temporary = true;

        /* Fallback title from filename (strip extension). */
        string basename = file.filename;
        int dot = basename.last_index_of_char ('.');
        if (dot > 0) {
            basename = basename.substring (0, dot);
        }
        media.title = basename;

        /* Try to pull real tags from the device. */
        unowned Mtp.Device? dev = mtp;
        if (dev != null) {
            var track = dev.get_trackmetadata (file.item_id);
            if (track != null) {
                if (track.title != null && track.title.strip ().length > 0) {
                    media.title = track.title.strip ();
                }
                if (track.artist != null && track.artist.strip ().length > 0) {
                    media.artist = track.artist.strip ();
                }
                if (track.album != null && track.album.strip ().length > 0) {
                    media.album = track.album.strip ();
                }
                if (track.genre != null && track.genre.strip ().length > 0) {
                    media.genre = track.genre.strip ();
                }
                if (track.composer != null && track.composer.strip ().length > 0) {
                    media.composer = track.composer.strip ();
                }
                if (track.tracknumber > 0) {
                    media.track = track.tracknumber;
                }
                if (track.duration > 0) {
                    media.length = track.duration; /* already in ms */
                }
                if (track.bitrate > 0) {
                    media.bitrate = track.bitrate;
                }
                if (track.samplerate > 0) {
                    media.samplerate = track.samplerate;
                }
                /* Track is freed automatically when it goes out of scope. */
            }
        }

        return media;
    }

    public override void add_files_to_library (Gee.Collection<string> files) {
    }

    /*
     * Import selected device tracks into the local Music library.
     * Downloads each MTP object into the user's Music folder, then adds
     * the resulting local file to libraries_manager.local_library.
     */
    public override void add_medias (Gee.Collection<Music.Media> list) {
        if (is_doing_file_operations) {
            warning ("[MTP library] Import already in progress");
            return;
        }
        if (list.size == 0) {
            return;
        }

        is_doing_file_operations = true;
        operation_cancelled = false;
        libraries_manager.current_operation = _("Importing <b>%d</b> track(s) from <b>%s</b>…")
            .printf (list.size, device.get_display_name ());
        Timeout.add (500, libraries_manager.do_progress_notification_with_timeout);
        import_medias_async.begin (list);
    }

    /*
     * libmtp progress callback. Updates the global progress bar using both
     * the overall file index and the bytes transferred for the current file.
     * Returning non-zero cancels the transfer.
     */
    private static int transfer_progress_cb (uint64 sent, uint64 total, void* data) {
        var ctx = (TransferContext) data;
        if (ctx == null || ctx.library == null) {
            return 0;
        }

        if (ctx.library.operation_cancelled) {
            return 1; /* cancel */
        }

        if (total > 0 && ctx.total > 0) {
            double file_frac = (double) sent / (double) total;
            double overall = ((double) ctx.index + file_frac) / (double) ctx.total;
            libraries_manager.progress = overall.clamp (0.0, 1.0);
        }

        return 0; /* continue */
    }

    private async void import_medias_async (Gee.Collection<Music.Media> to_import) {
        var local = libraries_manager.local_library;
        if (local == null) {
            warning ("[MTP library] No local library available for import");
            is_doing_file_operations = false;
            file_operations_done ();
            return;
        }

        string music_dir = Environment.get_user_special_dir (UserDirectory.MUSIC);
        if (music_dir == null || music_dir == "") {
            music_dir = Path.build_filename (Environment.get_home_dir (), "Music");
        }

        int total = to_import.size;
        int index = 0;
        int imported = 0;

        var ctx = new TransferContext ();
        ctx.library = this;
        ctx.total = total;

        foreach (var m in to_import) {
            if (operation_cancelled) {
                break;
            }

            uint32 item_id = get_item_id (m.uri);
            if (item_id == 0) {
                warning ("[MTP library] No item_id for %s — skipping", m.uri);
                index++;
                libraries_manager.progress = (double) index / total;
                continue;
            }

            string ext = ".mp3";
            int dot = m.uri.last_index_of_char ('.');
            if (dot > 0 && m.uri.length - dot <= 5) {
                ext = m.uri.substring (dot).down ();
            }

            string safe_title = (m.title ?? "track").replace ("/", "_").replace ("\\", "_");
            if (safe_title.strip () == "") {
                safe_title = "track";
            }
            string dest_name = "%s%s".printf (safe_title, ext);
            string dest_path = Path.build_filename (music_dir, dest_name);

            /* Avoid clobbering an existing file with the same name. */
            int suffix = 1;
            while (File.new_for_path (dest_path).query_exists ()) {
                dest_name = "%s (%d)%s".printf (safe_title, suffix, ext);
                dest_path = Path.build_filename (music_dir, dest_name);
                suffix++;
            }

            unowned Mtp.Device? dev = mtp;
            if (dev == null) {
                warning ("[MTP library] MTP session gone — aborting import");
                break;
            }

            ctx.index = index;
            print ("[MTP library] Importing %s → %s\n", m.title ?? "?", dest_path);

            /* Prefer the track API for audio; fall back to generic file API. */
            int ret = dev.get_track_to_file (item_id, dest_path, transfer_progress_cb, ctx);
            if (ret != 0) {
                /* Track call can fail on some devices; retry with file API. */
                ret = dev.get_file_to_file (item_id, dest_path, transfer_progress_cb, ctx);
            }

            if (ret != 0) {
                warning ("[MTP library] transfer failed (%d) for %s", ret, m.title ?? "?");
                try {
                    var f = File.new_for_path (dest_path);
                    if (f.query_exists ()) {
                        f.delete ();
                    }
                } catch (Error e) {}
            } else {
                var files = new Gee.ArrayList<string> ();
                files.add (dest_path);
                local.add_files_to_library (files);
                imported++;
            }

            index++;
            libraries_manager.progress = (double) index / total;
        }

        print ("[MTP library] Imported %d / %d track(s)\n", imported, total);

        Idle.add (() => {
            is_doing_file_operations = false;
            file_operations_done ();
            operation_cancelled = false;
            return false;
        });
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
