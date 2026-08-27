// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Reusable device settings panel: H4 title above a framed content area.
 * Subclasses (or callers) pack widgets into {@link content}.
 */

public class Music.DevicePanel : Gtk.Box {
    public Gtk.Label title_label { get; private set; }
    public Gtk.Box content { get; private set; }
    public Gtk.Frame frame { get; private set; }

    public DevicePanel (string title) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);

        title_label = new Gtk.Label (title);
        title_label.xalign = 0;
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        content.margin = 12;

        frame = new Gtk.Frame (null);
        frame.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        frame.add (content);

        pack_start (title_label, false, false, 0);
        pack_start (frame, false, false, 0);
    }

    public void set_title (string title) {
        title_label.label = title;
    }
}
