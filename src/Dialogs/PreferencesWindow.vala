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

public class Music.PreferencesWindow : Hdy.ApplicationWindow {
    public PreferencesWindow () {
        Object (
            destroy_with_parent: true,
            resizable: false,
            title: _("Preferences"),
            transient_for: App.main_window
        );
    }

    construct {
        var headerbar = new Hdy.HeaderBar ();
        headerbar.set_title (_("Settings"));
        headerbar.set_has_subtitle (false);
        headerbar.show_all ();

        var library_filechooser = new Gtk.FileChooserButton (_("Select Music Folder…"), Gtk.FileChooserAction.SELECT_FOLDER);
        library_filechooser.hexpand = true;
        library_filechooser.set_current_folder (Settings.Main.get_default ().music_folder);
        library_filechooser.file_set.connect (() => {
            string? filename = library_filechooser.get_filename ();
            App.main_window.set_music_folder (filename);
        });

        var main_settings = Settings.Main.get_default ();

        var organize_folders_switch = new Gtk.Switch ();
        organize_folders_switch.halign = Gtk.Align.START;
        main_settings.schema.bind ("update-folder-hierarchy", organize_folders_switch, "active", SettingsBindFlags.DEFAULT);

        var write_file_metadata_switch = new Gtk.Switch ();
        write_file_metadata_switch.halign = Gtk.Align.START;
        main_settings.schema.bind ("write-metadata-to-file", write_file_metadata_switch, "active", SettingsBindFlags.DEFAULT);

        var copy_imported_music_switch = new Gtk.Switch ();
        copy_imported_music_switch.halign = Gtk.Align.START;
        main_settings.schema.bind ("copy-imported-music", copy_imported_music_switch, "active", SettingsBindFlags.DEFAULT);

        var enable_smart_playlists_switch = new Gtk.Switch ();
        enable_smart_playlists_switch.halign = Gtk.Align.START;
        main_settings.schema.bind ("enable-smart-playlists", enable_smart_playlists_switch, "active", SettingsBindFlags.DEFAULT);

        var enable_headless_playlists_switch = new Gtk.Switch ();
        enable_headless_playlists_switch.halign = Gtk.Align.START;
        main_settings.schema.bind ("enable-headless-playlists", enable_headless_playlists_switch, "active", SettingsBindFlags.DEFAULT);

        var layout = new Gtk.Grid ();
        layout.column_spacing = 12;
        layout.margin = 6;
        layout.row_spacing = 6;
        layout.attach (new SettingsHeaderLabel (_("Music Folder Location")), 0, 0);
        layout.attach (library_filechooser, 0, 1, 2, 1);
        layout.attach (new SettingsHeaderLabel (_("Library Management")), 0, 2);
        layout.attach (new SettingsLabel (_("Keep Music folder organized:")), 0, 3);
        layout.attach (organize_folders_switch, 1, 3);
        layout.attach (new SettingsLabel (_("Write metadata to file:")), 0, 4);
        layout.attach (write_file_metadata_switch, 1, 4);
        layout.attach (new SettingsLabel (_("Copy imported files to Library:")), 0, 5);
        layout.attach (copy_imported_music_switch, 1, 5);
        layout.attach (new SettingsHeaderLabel (_("Look & Feel")), 0, 6);
        layout.attach (new SettingsLabel (_("Enabe smart playlists")), 0, 7);
        layout.attach (enable_smart_playlists_switch, 1, 7);
        layout.attach (new SettingsLabel (_("Enabe headless playlists")), 0, 8);
        layout.attach (enable_headless_playlists_switch, 1, 8);

        var close_button = new Gtk.Button ();
        close_button.label = _("Close");
        close_button.clicked.connect (() => destroy ());
        close_button.halign = Gtk.Align.END;
        close_button.margin_end = 5;
        close_button.margin_bottom = 5;

        var grid = new Gtk.Grid ();
        grid.attach (headerbar, 0, 0);
        grid.attach (layout, 0, 1);
        grid.attach (close_button, 0, 2);
        grid.show_all ();

        add (grid);

        //FIXME: don't know if I can delete this
        Plugins.Manager.get_default ().hook_preferences_window (this);
    }

    private class SettingsHeaderLabel : Gtk.Stack {
        public SettingsHeaderLabel (string text) {
            var header_label = new Granite.HeaderLabel (_(text));
            hexpand = true;
            add (header_label);
        }
    }

    private class SettingsLabel : Gtk.Label {
        public SettingsLabel (string text) {
            label = text;
            halign = Gtk.Align.END;
            hexpand = true;
            margin_start = 12;
        }
    }

}
