// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Compact 2-column form, centered horizontally and vertically.
 * All binary prefs are checkboxes. Storage bar stays at the bottom.
 * Recovery UI gated by device.can_recover ().
 */

public class Music.DeviceSummaryWidget : Gtk.EventBox {
    public Device device { get; construct; }
    public DevicePreferences preferences { get; construct; }

    private Gtk.Button sync_button;
    private Gtk.CheckButton sync_music_check;
    private Gtk.ComboBox sync_music_combobox;
    private Gtk.ListStore music_list;
    private Gtk.CheckButton auto_sync_check;
    private Gtk.Label encrypt_label;
    private Gtk.CheckButton encrypt_check;
    private Gtk.Button backup_button;
    private Gtk.Button restore_button;
    private Gtk.Box backup_box;
    private Granite.Widgets.StorageBar storagebar;

    public DeviceSummaryWidget (Device device, DevicePreferences preferences) {
        Object (
            device: device,
            preferences: preferences
        );
    }

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        var auto_sync_label = new Gtk.Label (_("Automatically sync when plugged in:"));
        auto_sync_label.halign = Gtk.Align.END;
        auto_sync_label.xalign = 1;
        auto_sync_label.valign = Gtk.Align.CENTER;

        auto_sync_check = new Gtk.CheckButton ();
        auto_sync_check.halign = Gtk.Align.START;
        auto_sync_check.valign = Gtk.Align.CENTER;

        encrypt_label = new Gtk.Label (_("Encrypt local backup:"));
        encrypt_label.halign = Gtk.Align.END;
        encrypt_label.xalign = 1;
        encrypt_label.valign = Gtk.Align.CENTER;

        encrypt_check = new Gtk.CheckButton ();
        encrypt_check.halign = Gtk.Align.START;
        encrypt_check.valign = Gtk.Align.CENTER;
        encrypt_check.tooltip_text = _("Encrypt backups with a password");

        var sync_options_label = new Gtk.Label (_("Sync:"));
        sync_options_label.halign = Gtk.Align.END;
        sync_options_label.xalign = 1;
        sync_options_label.valign = Gtk.Align.CENTER;

        sync_music_check = new Gtk.CheckButton ();
        sync_music_check.halign = Gtk.Align.START;
        sync_music_check.valign = Gtk.Align.CENTER;

        music_list = new Gtk.ListStore (3, typeof (GLib.Object), typeof (string), typeof (GLib.Icon));

        var music_cell = new Gtk.CellRendererPixbuf ();
        music_cell.stock_size = Gtk.IconSize.MENU;

        var cell = new Gtk.CellRendererText ();
        cell.ellipsize = Pango.EllipsizeMode.END;

        sync_music_combobox = new Gtk.ComboBox ();
        sync_music_combobox.set_model (music_list);
        sync_music_combobox.set_id_column (1);
        sync_music_combobox.set_row_separator_func (row_separator_func);
        sync_music_combobox.pack_start (music_cell, false);
        sync_music_combobox.add_attribute (music_cell, "gicon", 2);
        sync_music_combobox.pack_start (cell, true);
        sync_music_combobox.add_attribute (cell, "text", 1);
        sync_music_combobox.popup.connect (refresh_lists);
        sync_music_combobox.halign = Gtk.Align.START;
        sync_music_combobox.valign = Gtk.Align.CENTER;
        sync_music_combobox.width_request = 220;
        sync_music_combobox.set_button_sensitivity (Gtk.SensitivityType.ON);

        var sync_controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        sync_controls.halign = Gtk.Align.START;
        sync_controls.pack_start (sync_music_check, false, false, 0);
        sync_controls.pack_start (sync_music_combobox, false, false, 0);

        backup_button = new Gtk.Button.with_label (_("Back Up Now"));
        backup_button.clicked.connect (() => {
            device.backup_device (encrypt_check.active);
        });

        restore_button = new Gtk.Button.with_label (_("Restore"));
        restore_button.clicked.connect (() => {
            device.restore_device ();
        });

        backup_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        backup_box.halign = Gtk.Align.START;
        backup_box.pack_start (backup_button, false, false, 0);
        backup_box.pack_start (restore_button, false, false, 0);

        var form = new Gtk.Grid ();
        form.column_spacing = 12;
        form.row_spacing = 8;
        form.halign = Gtk.Align.CENTER;
        form.valign = Gtk.Align.CENTER;

        form.attach (auto_sync_label,    0, 0, 1, 1);
        form.attach (auto_sync_check,    1, 0, 1, 1);
        form.attach (encrypt_label,      0, 1, 1, 1);
        form.attach (encrypt_check,      1, 1, 1, 1);
        form.attach (sync_options_label, 0, 2, 1, 1);
        form.attach (sync_controls,      1, 2, 1, 1);
        form.attach (backup_box,         1, 3, 1, 1);

        var form_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        form_area.hexpand = true;
        form_area.vexpand = true;
        form_area.pack_start (form, true, false, 0);

        uint64 capacity = device.get_capacity ();
        if (capacity == 0) {
            capacity = 32ULL * 1024 * 1024 * 1024;
        }

        uint64 used = device.get_used_space ();
        if (used == 0) {
            used = 20ULL * 1024 * 1024 * 1024;
        }

        storagebar = new Granite.Widgets.StorageBar.with_total_usage (capacity, used);

        sync_button = new Gtk.Button.with_label (_("Sync"));
        sync_button.valign = Gtk.Align.CENTER;
        sync_button.width_request = 80;

        var storage_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        storage_row.margin = 24;
        storage_row.margin_bottom = 6;
        storage_row.pack_start (storagebar, true, true, 0);
        storage_row.pack_start (sync_button, false, false, 0);

        var storage_toolbar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        storage_toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        storage_toolbar.pack_start (storage_row, false, false, 0);

        refresh_space_widget ();

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.pack_start (form_area, true, true, 0);
        main_box.pack_end (storage_toolbar, false, false, 0);

        add (main_box);

        refresh_lists ();

        auto_sync_check.active = preferences.sync_when_mounted;
        sync_music_check.active = preferences.sync_music;

        if (preferences.sync_all_music || preferences.music_playlist == null) {
            sync_music_combobox.set_active (0);
        } else {
            bool success = sync_music_combobox.set_active_id (preferences.music_playlist.name);
            if (!success) {
                preferences.music_playlist = null;
                preferences.sync_all_music = true;
                sync_music_combobox.set_active (0);
            }
        }

        auto_sync_check.toggled.connect (save_preferences);
        sync_music_check.toggled.connect (save_preferences);
        sync_music_combobox.changed.connect (save_preferences);

        sync_button.clicked.connect (sync_clicked);

        device.get_library ().file_operations_done.connect (() => {
            refresh_space_widget ();
            sync_button.sensitive = true;
        });

        device.initialized.connect (() => {
            refresh_space_widget ();
            apply_recover_section_visibility ();
        });

        libraries_manager.local_library.playlist_added.connect (() => {refresh_lists ();});
        libraries_manager.local_library.playlist_name_updated.connect (() => {refresh_lists ();});
        libraries_manager.local_library.playlist_removed.connect (() => {refresh_lists ();});
        libraries_manager.local_library.smartplaylist_added.connect (() => {refresh_lists ();});
        libraries_manager.local_library.smartplaylist_name_updated.connect (() => {refresh_lists ();});
        libraries_manager.local_library.smartplaylist_removed.connect (() => {refresh_lists ();});

        show_all ();
        apply_recover_section_visibility ();
    }

    private void apply_recover_section_visibility () {
        bool show = device.can_recover ();

        encrypt_label.visible = show;
        encrypt_check.visible = show;
        backup_button.visible = show;
        restore_button.visible = show;
        backup_box.visible = show;
    }

    private void refresh_space_widget () {
        uint64 audio = 0;
        uint64 video = 0;
        uint64 photo = 0;
        uint64 app = 0;

        foreach (var m in device.get_library ().get_medias ()) {
            if (m == null || m.file_size == 0) {
                continue;
            }

            var uri = (m.uri ?? "").down ();
            if (uri.has_suffix (".mp3") || uri.has_suffix (".flac") || uri.has_suffix (".m4a")
                || uri.has_suffix (".ogg") || uri.has_suffix (".wav") || uri.has_suffix (".aac")
                || uri.has_suffix (".opus") || uri.has_suffix (".wma") || uri.has_suffix (".aiff")) {
                audio += m.file_size;
            } else if (uri.has_suffix (".mp4") || uri.has_suffix (".mkv") || uri.has_suffix (".avi")
                || uri.has_suffix (".mov") || uri.has_suffix (".webm") || uri.has_suffix (".3gp")
                || uri.has_suffix (".m4v")) {
                video += m.file_size;
            } else if (uri.has_suffix (".jpg") || uri.has_suffix (".jpeg") || uri.has_suffix (".png")
                || uri.has_suffix (".gif") || uri.has_suffix (".webp") || uri.has_suffix (".heic")
                || uri.has_suffix (".bmp")) {
                photo += m.file_size;
            } else if (uri.has_suffix (".apk")) {
                app += m.file_size;
            } else {
                audio += m.file_size;
            }
        }

        if (audio + video + photo + app == 0) {
            audio = 4ULL * 1024 * 1024 * 1024;
            video = 3ULL * 1024 * 1024 * 1024;
            photo = 2ULL * 1024 * 1024 * 1024;
            app = 1ULL * 1024 * 1024 * 1024;
        }

        uint64 accounted = audio + video + photo + app;
        uint64 used = device.get_used_space ();
        if (used == 0) {
            used = accounted + (2ULL * 1024 * 1024 * 1024);
        }

        uint64 other = used > accounted ? used - accounted : 0;

        uint64 capacity = device.get_capacity ();
        if (capacity == 0) {
            capacity = 32ULL * 1024 * 1024 * 1024;
        }

        storagebar.storage = capacity;
        storagebar.total_usage = used;

        storagebar.update_block_size (Granite.Widgets.StorageBar.ItemDescription.AUDIO, audio);
        storagebar.update_block_size (Granite.Widgets.StorageBar.ItemDescription.VIDEO, video);
        storagebar.update_block_size (Granite.Widgets.StorageBar.ItemDescription.PHOTO, photo);
        storagebar.update_block_size (Granite.Widgets.StorageBar.ItemDescription.APP, app);
        storagebar.update_block_size (Granite.Widgets.StorageBar.ItemDescription.FILES, other);
    }

    private bool row_separator_func (Gtk.TreeModel model, Gtk.TreeIter iter) {
        string sep = "";
        model.get (iter, 1, out sep);
        return sep == "<separator_item_unique_name>";
    }

    private void save_preferences () {
        preferences.sync_when_mounted = auto_sync_check.active;
        preferences.sync_music = sync_music_check.active;
        preferences.sync_all_music = sync_music_combobox.get_active () == 0;
        Gtk.TreeIter iter;
        if (sync_music_combobox.get_active () - 2 >= 0) {
            sync_music_combobox.get_active_iter (out iter);
            GLib.Value value;
            music_list.get_value (iter, 0, out value);
            preferences.music_playlist = (Music.Playlist) value.dup_object ();
        }

        sync_music_combobox.sensitive = sync_music_check.active;
    }

    private void refresh_lists () {
        Gtk.TreeIter iter;
        Playlist selected_playlist = null;
        if (sync_music_combobox.get_active () - 2 >= 0) {
            sync_music_combobox.get_active_iter (out iter);
            GLib.Value value;
            music_list.get_value (iter, 0, out value);
            selected_playlist = (Music.Playlist) value.dup_object ();
        }

        music_list.clear ();

        music_list.append (out iter);
        music_list.set (iter, 0, null, 1, _("All Music"), 2, new ThemedIcon ("library-music"));

        music_list.append (out iter);
        music_list.set (iter, 0, null, 1, "<separator_item_unique_name>");

        foreach (var p in libraries_manager.local_library.get_smart_playlists ()) {
            music_list.append (out iter);
            music_list.set (iter, 0, p, 1, p.name, 2, p.icon);
            if (selected_playlist == p) {
                sync_music_combobox.set_active_iter (iter);
            }
        }

        foreach (var p in libraries_manager.local_library.get_playlists ()) {
            if (p.read_only == false) {
                music_list.append (out iter);
                music_list.set (iter, 0, p, 1, p.name, 2, p.icon);
                if (selected_playlist == p) {
                    sync_music_combobox.set_active_iter (iter);
                }
            }
        }

        if (selected_playlist == null) {
            sync_music_combobox.set_active (0);
        }

        sync_music_combobox.sensitive = preferences.sync_music;
    }

    public void sync_clicked () {
        var list = new Gee.TreeSet<Media> ();

        if (preferences.sync_music) {
            if (preferences.sync_all_music) {
                foreach (var s in libraries_manager.local_library.get_medias ()) {
                    if (s.is_temporary == false) {
                        list.add (s);
                    }
                }
            } else {
                var p = preferences.music_playlist;

                if (p != null) {
                    foreach (var m in p) {
                        if (m != null) {
                            list.add (m);
                        }
                    }
                } else {
                    NotificationManager.get_default ().show_alert (
                        _("Sync Failed"),
                        _("The playlist named %s is used to sync device %s, but could not be found.").printf (
                            "<b>" + preferences.music_playlist.name + "</b>",
                            "<b>" + device.get_display_name () + "</b>"
                        )
                    );

                    preferences.music_playlist = null;
                    preferences.sync_all_music = true;
                    sync_music_combobox.set_active (0);
                    return;
                }
            }
        }

        bool fits = device.will_fit (list);
        if (!fits) {
            NotificationManager.get_default ().show_alert (
                _("Cannot Sync"),
                _("Cannot sync device with selected sync settings. Not enough space on disk")
            );
        } else if (device.get_library ().doing_file_operations ()) {
            NotificationManager.get_default ().show_alert (
                _("Cannot Sync"),
                _("Device is already doing an operation.")
            );
        } else {
            var found = new Gee.TreeSet<int> ();
            var not_found = new Gee.TreeSet<Media> ();
            libraries_manager.local_library.media_from_name (device.get_library ().get_medias (), found, not_found);

            if (not_found.size > 0) {
                var swd = new SyncWarningDialog (device, list, not_found);
                swd.response.connect ((src, id) => {
                    switch (id) {
                        case SyncWarningDialog.ResponseId.IMPORT_MEDIA:
                            libraries_manager.transfer_to_local_library (not_found);
                            swd.destroy ();
                            break;
                        case SyncWarningDialog.ResponseId.CONTINUE:
                            device.synchronize ();
                            swd.destroy ();
                            break;
                        case SyncWarningDialog.ResponseId.STOP:
                            swd.destroy ();
                            break;
                    }
                });
            } else {
                sync_button.sensitive = false;
                device.synchronize ();
            }
        }
    }
}
