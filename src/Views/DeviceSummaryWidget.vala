// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012-2018 elementary LLC. (https://elementary.io)
 *
 * Stock device summary — sync options + storage bar.
 * Device name lives in DeviceHardwareInfo (click to rename).
 */

public class Music.DeviceSummaryWidget : Gtk.EventBox {
    public Device device { get; construct; }
    public DevicePreferences preferences { get; construct; }

    private Gtk.Button sync_button;
    private Gtk.CheckButton sync_music_check;
    private Gtk.ComboBox sync_music_combobox;
    private Gtk.ListStore music_list;
    private Gtk.Switch auto_sync_switch;
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

        auto_sync_switch = new Gtk.Switch ();
        auto_sync_switch.halign = Gtk.Align.START;

        var sync_options_label = new Gtk.Label (_("Sync:"));
        sync_options_label.halign = Gtk.Align.END;

        sync_music_check = new Gtk.CheckButton ();

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
        sync_music_combobox.set_button_sensitivity (Gtk.SensitivityType.ON);

        uint64 capacity = device.get_capacity ();
        if (capacity == 0) {
            capacity = 1;
        }

        storagebar = new Granite.Widgets.StorageBar.with_total_usage (capacity, device.get_used_space ());

        sync_button = new Gtk.Button.with_label (_("Sync"));
        sync_button.valign = Gtk.Align.CENTER;
        sync_button.width_request = 80;

        var storage_grid = new Gtk.Grid ();
        storage_grid.column_spacing = 6;
        storage_grid.margin = 24;
        storage_grid.add (storagebar);
        storage_grid.add (sync_button);

        var storage_toolbar = new Gtk.Grid ();
        storage_toolbar.valign = Gtk.Align.END;
        storage_toolbar.add (storage_grid);
        storage_toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

        refresh_space_widget ();

        var content_grid = new Gtk.Grid ();
        content_grid.expand = true;
        content_grid.halign = Gtk.Align.CENTER;
        content_grid.row_spacing = 6;
        content_grid.column_spacing = 12;
        content_grid.margin_top = 12;

        content_grid.attach (auto_sync_label, 1, 0, 1, 1);
        content_grid.attach (auto_sync_switch, 2, 0, 2, 1);
        content_grid.attach (sync_options_label, 1, 1, 1, 1);
        content_grid.attach (sync_music_check, 2, 1, 1, 1);
        content_grid.attach (sync_music_combobox, 3, 1, 1, 1);

        var main_grid = new Gtk.Grid ();
        main_grid.attach (content_grid, 0, 0, 1, 1);
        main_grid.attach (storage_toolbar, 0, 1, 1, 1);

        add (main_grid);

        refresh_lists ();

        auto_sync_switch.active = preferences.sync_when_mounted;
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

        auto_sync_switch.notify["active"].connect (save_preferences);
        sync_music_check.toggled.connect (save_preferences);
        sync_music_combobox.changed.connect (save_preferences);

        sync_button.clicked.connect (sync_clicked);

        device.get_library ().file_operations_done.connect (() => {
            refresh_space_widget ();
            sync_button.sensitive = true;
        });

        device.initialized.connect (() => {
            refresh_space_widget ();
        });

        libraries_manager.local_library.playlist_added.connect (() => {refresh_lists ();});
        libraries_manager.local_library.playlist_name_updated.connect (() => {refresh_lists ();});
        libraries_manager.local_library.playlist_removed.connect (() => {refresh_lists ();});
        libraries_manager.local_library.smartplaylist_added.connect (() => {refresh_lists ();});
        libraries_manager.local_library.smartplaylist_name_updated.connect (() => {refresh_lists ();});
        libraries_manager.local_library.smartplaylist_removed.connect (() => {refresh_lists ();});
        show_all ();
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

        uint64 accounted = audio + video + photo + app;
        uint64 used = device.get_used_space ();
        uint64 other = used > accounted ? used - accounted : 0;

        uint64 capacity = device.get_capacity ();
        if (capacity == 0) {
            capacity = 1;
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
        preferences.sync_when_mounted = auto_sync_switch.active;
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
