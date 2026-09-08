// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* CD burn UI.
 *
 * Stacked below the normal DeviceSummaryWidget + library list by
 * DeviceView (row 1). Shows a storage bar (track count / used / free)
 * and a Burn button that opens the burn dialog.
 */

public class Music.Plugins.CDView : Gtk.Box {
    private CDLibrary library;
    private CDDevice device;

    private Gtk.LevelBar storage_bar;
    private Gtk.Label storage_label;
    private Gtk.Button burn_button;

    /* Blank audio CD capacity: 74:33 of 44100 Hz 16-bit stereo = 681984000 bytes. */
    private const uint64 CD_CAPACITY = 681984000;
    private const uint BYTES_PER_SECTOR = 2352;
    private const uint SECTORS_PER_SEC = 75;

    public CDView (CDDevice device, CDLibrary library) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
        this.device = device;
        this.library = library;

        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        toolbar.margin = 12;

        storage_bar = new Gtk.LevelBar.for_interval (0, CD_CAPACITY);
        storage_bar.hexpand = true;
        storage_bar.mode = Gtk.LevelBarMode.CONTINUOUS;

        storage_label = new Gtk.Label ("");
        storage_label.xalign = 0;

        burn_button = new Gtk.Button.with_label (_("Burn"));
        burn_button.get_style_context ().add_class ("suggested-action");
        burn_button.clicked.connect (on_burn_clicked);

        toolbar.pack_start (storage_bar, true, true, 0);
        toolbar.pack_start (storage_label, false, false, 0);
        toolbar.pack_end (burn_button, false, false, 0);

        pack_start (toolbar, false, false, 0);

        library.media_added.connect (on_media_changed);
        library.search_finished.connect (on_media_changed);
        update_storage ();

        show_all ();
    }

    private void on_media_changed () {
        update_storage ();
    }

    private void update_storage () {
        uint track_count = 0;
        uint64 used = 0;
        foreach (var m in library.get_medias ()) {
            track_count++;
            double secs = m.length > 0 ? m.length / 1000.0 : 240.0;
            used += (uint64) (secs * SECTORS_PER_SEC * BYTES_PER_SECTOR);
        }

        uint64 free = CD_CAPACITY > used ? CD_CAPACITY - used : 0;
        storage_bar.set_value (used);

        storage_label.label = _("%u tracks · %s used · %s free").printf (
            track_count,
            format_size (used),
            format_size (free));
    }

    private string format_size (uint64 bytes) {
        if (bytes >= 1024 * 1024) {
            return "%.1f MB".printf (bytes / (1024.0 * 1024.0));
        }
        if (bytes >= 1024) {
            return "%.0f KB".printf (bytes / 1024.0);
        }
        return "%llu B".printf (bytes);
    }

    private void on_burn_clicked () {
        var dlg = new CDBurnDialog (device, library);
        dlg.set_transient_for ((Gtk.Window) get_toplevel ());
        dlg.show_all ();
    }
}

/* Simple burn dialog: lists tracks to burn and a Start button.
 * Actual libburn writing is a follow-up; this gives the UI surface. */
public class Music.Plugins.CDBurnDialog : Gtk.Dialog {
    private CDLibrary library;
    private Gtk.ListBox list;

    public CDBurnDialog (CDDevice device, CDLibrary library) {
        Object (title: _("Burn Audio CD"), use_header_bar: 1);
        this.library = library;
        set_default_size (420, 360);

        var content = get_content_area ();
        content.spacing = 12;
        content.margin = 12;

        var info = new Gtk.Label (_("Select tracks to write to the disc:"));
        info.xalign = 0;
        content.pack_start (info, false, false, 0);

        list = new Gtk.ListBox ();
        list.selection_mode = Gtk.SelectionMode.NONE;
        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.add (list);
        scroll.expand = true;
        content.pack_start (scroll, true, true, 0);

        foreach (var m in library.get_medias ()) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var check = new Gtk.CheckButton ();
            check.active = true;
            var lbl = new Gtk.Label (m.get_display_name ());
            lbl.xalign = 0;
            lbl.hexpand = true;
            box.pack_start (check, false, false, 0);
            box.pack_start (lbl, true, true, 0);
            row.add (box);
            list.add (row);
        }

        var start = add_button (_("_Start Burn"), Gtk.ResponseType.ACCEPT);
        start.get_style_context ().add_class ("suggested-action");
        add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);

        show_all ();
    }
}
