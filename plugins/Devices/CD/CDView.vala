// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Track list for audio CDs.
 *
 * Returned from CDDevice.get_custom_view() so DeviceView never renders the
 * summary page (storage bar / sync). Updates live as GVFS lists tracks.
 */

public class Music.Plugins.CDView : Gtk.Box {
    private CDLibrary library;
    private CDDevice device;
    private Gtk.ListBox list_box;
    private Gtk.Stack stack;
    private Granite.Widgets.AlertView empty_view;

    public CDView (CDDevice device, CDLibrary library) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        this.device = device;
        this.library = library;

        empty_view = new Granite.Widgets.AlertView (
            device.get_empty_device_title (),
            device.get_empty_device_description (),
            "media-optical"
        );

        list_box = new Gtk.ListBox ();
        list_box.selection_mode = Gtk.SelectionMode.MULTIPLE;
        list_box.activate_on_single_click = false;
        list_box.row_activated.connect (on_row_activated);

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.expand = true;
        scrolled.add (list_box);

        stack = new Gtk.Stack ();
        stack.expand = true;
        stack.add_named (empty_view, "empty");
        stack.add_named (scrolled, "list");
        stack.visible_child_name = "empty";

        pack_start (stack, true, true, 0);

        library.media_added.connect ((added) => {
            foreach (var m in added) {
                add_row (m);
            }
            refresh_empty_state ();
        });

        foreach (var m in library.get_medias ()) {
            add_row (m);
        }
        refresh_empty_state ();
        show_all ();
    }

    private void add_row (Media m) {
        var row = new TrackRow (m);
        list_box.add (row);
        row.show_all ();
    }

    private void refresh_empty_state () {
        bool has = false;
        list_box.foreach (() => { has = true; });
        stack.visible_child_name = has ? "list" : "empty";
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        var track_row = row as TrackRow;
        if (track_row == null) {
            return;
        }

        var medias = new Gee.ArrayList<Media> ();
        list_box.foreach ((child) => {
            var tr = child as TrackRow;
            if (tr != null) {
                medias.add (tr.media);
            }
        });

        App.player.clear_queue ();
        App.player.queue_media (medias);
        App.player.play_media (track_row.media);
        App.player.start_playback ();
    }

    private class TrackRow : Gtk.ListBoxRow {
        public Media media { get; private set; }

        public TrackRow (Media media) {
            this.media = media;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.margin = 6;

            var track_label = new Gtk.Label ("%u".printf (media.track));
            track_label.xalign = 1.0f;
            track_label.width_chars = 3;
            track_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            var title_label = new Gtk.Label (media.title);
            title_label.xalign = 0.0f;
            title_label.hexpand = true;
            title_label.ellipsize = Pango.EllipsizeMode.END;

            string length_text = "";
            if (media.length > 0) {
                uint secs = media.length / 1000;
                length_text = "%u:%02u".printf (secs / 60, secs % 60);
            }
            var length_label = new Gtk.Label (length_text);
            length_label.xalign = 1.0f;
            length_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            grid.attach (track_label, 0, 0);
            grid.attach (title_label, 1, 0);
            grid.attach (length_label, 2, 0);
            add (grid);
        }
    }
}
