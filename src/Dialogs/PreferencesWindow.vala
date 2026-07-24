// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012-2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Music authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Music. This permission is above and beyond the permissions granted
 * by the GPL license by which Music is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 */

public class Music.PreferencesWindow : Hdy.PreferencesWindow {
    public PreferencesWindow () {
        Object (
            resizable: false,
            deletable: false,
            title: _("Preferences"),
            destroy_with_parent: true
        );
    }

    construct {
        var main_settings = Settings.Main.get_default ();
        /*
         * File chooser
         */
        var library_filechooser = new Gtk.FileChooserButton (
            _("Select Music Folder…"),
            Gtk.FileChooserAction.SELECT_FOLDER
        );
        library_filechooser.hexpand = true;
        library_filechooser.set_current_folder (
            main_settings.music_folder
        );

        library_filechooser.file_set.connect (() => {
            string? filename = library_filechooser.get_filename ();
            App.main_window.set_music_folder (filename);
        });

        /*
         * Switches
         */

        var organize_folders_switch = new Gtk.Switch ();
        var write_file_metadata_switch = new Gtk.Switch ();
        var copy_imported_music_switch = new Gtk.Switch ();
        var enable_smart_playlists_switch = new Gtk.Switch ();
        var enable_headless_playlists_switch = new Gtk.Switch ();

        organize_folders_switch.valign = Gtk.Align.CENTER;
        write_file_metadata_switch.valign = Gtk.Align.CENTER;
        copy_imported_music_switch.valign = Gtk.Align.CENTER;
        enable_smart_playlists_switch.valign = Gtk.Align.CENTER;
        enable_headless_playlists_switch.valign = Gtk.Align.CENTER;

        main_settings.schema.bind (
            "update-folder-hierarchy",
            organize_folders_switch,
            "active",
            SettingsBindFlags.DEFAULT
        );

        main_settings.schema.bind (
            "write-metadata-to-file",
            write_file_metadata_switch,
            "active",
            SettingsBindFlags.DEFAULT
        );

        main_settings.schema.bind (
            "copy-imported-music",
            copy_imported_music_switch,
            "active",
            SettingsBindFlags.DEFAULT
        );

        main_settings.schema.bind (
            "enable-smart-playlists",
            enable_smart_playlists_switch,
            "active",
            SettingsBindFlags.DEFAULT
        );

        main_settings.schema.bind (
            "enable-headless-playlists",
            enable_headless_playlists_switch,
            "active",
            SettingsBindFlags.DEFAULT
        );

        /*
         * GENERAL PAGE
         */

        var general_page = new Hdy.PreferencesPage ();
        general_page.title = _("General");
        general_page.icon_name = "preferences-system-symbolic";

        var music_group = new Hdy.PreferencesGroup ();
        music_group.title = _("Music Folder Location");

        var folder_grid = new Gtk.Grid ();
        folder_grid.column_spacing = 12;

        var folder_label = new Gtk.Label (_("Music Folder"));
        folder_label.halign = Gtk.Align.START;
        folder_label.hexpand = true;

        folder_grid.attach (folder_label, 0, 0, 1, 1);
        folder_grid.attach (library_filechooser, 1, 0, 1, 1);

        music_group.add (folder_grid);
        general_page.add (music_group);

        /*
         * LIBRARY PAGE
         */

        var library_page = new Hdy.PreferencesPage ();
        library_page.title = _("Library");
        library_page.icon_name = "folder-music-symbolic";

        var library_group = new Hdy.PreferencesGroup ();
        library_group.title = _("Library Management");

        library_group.add (make_row (_("Keep Music folder organized"), organize_folders_switch));
        library_group.add (make_row (_("Write metadata to file"), write_file_metadata_switch));
        library_group.add (make_row (_("Copy imported files to Library"), copy_imported_music_switch));

        library_page.add (library_group);

        /*
         * LOOK & FEEL PAGE
         */

        var playlist_page = new Hdy.PreferencesPage ();
        playlist_page.title = _("Playlist");
        playlist_page.icon_name = "view-list-symbolic";

        var playlist_group = new Hdy.PreferencesGroup ();
        playlist_group.title = _("Playlists Management");

        playlist_group.add (make_row (_("Enable smart playlists"), enable_smart_playlists_switch));
        playlist_group.add (make_row (_("Enable headless playlists"), enable_headless_playlists_switch));

        playlist_page.add (playlist_group);

        /*
         * ADD PAGES
         */

        add (general_page);
        add (library_page);
        add (playlist_page);

        Plugins.Manager.get_default ().hook_preferences_window (this);

        show_all ();
    }

    /*
     * Helper: replaces ActionRow completely
     */
    private Gtk.Widget make_row (string title, Gtk.Switch sw) {
        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.margin_top = 6;
        grid.margin_bottom = 6;

        var label = new Gtk.Label (title);
        label.halign = Gtk.Align.START;
        label.hexpand = true;

        sw.valign = Gtk.Align.CENTER;

        grid.attach (label, 0, 0, 1, 1);
        grid.attach (sw, 1, 0, 1, 1);

        return grid;
    }
}
