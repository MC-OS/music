// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Reusable section for the device / sync area:
 *   [ section title label ]   ← H4 label
 *   ┌─────────────────────┐
 *   │  STYLE_CLASS_VIEW   │   ← Gtk.Box (content_panel, packs directly)
 *   └─────────────────────┘
 */

public class Music.DevicePanel : Gtk.Box {
    public Gtk.Label panel_label { get; private set; }
    public Gtk.Box panel_content { get; private set; }
    private Gtk.Grid panel_frame { get; private set; }

    public DevicePanel (string title, Gtk.Orientation orientation = Gtk.Orientation.VERTICAL) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 0,
            hexpand: true
        );
        set_margin_start (0);
        set_margin_end (0);
        set_margin_top (0);
        set_margin_bottom (0);

        panel_label = new Gtk.Label (title);
        panel_label.xalign = 0;
        panel_label.set_margin_start (4);
        panel_label.set_margin_end (4);
        panel_label.set_margin_top (0);
        panel_label.set_margin_bottom (0);
        panel_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        panel_content = new Gtk.Box (orientation, 2);
        panel_content.set_margin_start (12);
        panel_content.set_margin_end (12);
        panel_content.set_margin_top (12);
        panel_content.set_margin_bottom (12);
        panel_content.set_hexpand (true);
        panel_content.set_vexpand (true);

        panel_frame = new Gtk.Grid ();
        panel_frame.set_margin_start (2);
        panel_frame.set_margin_end (2);
        panel_frame.set_margin_top (2);
        panel_frame.set_margin_bottom (2);
        panel_frame.set_hexpand (true);
        panel_frame.set_vexpand (true);
        panel_frame.add (panel_content);
        panel_frame.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        add (panel_label);
        add (panel_frame);
    }

    public void set_title (string title) {
        panel_label.label = title;
    }

    public void add_content (Gtk.Widget widget) {
        panel_content.add (widget);
    }

    public void pack_content_start (Gtk.Widget widget) {
        panel_content.pack_start (widget, false, false, 0);
    }

    public void pack_content_end (Gtk.Widget widget) {
        panel_content.pack_end (widget, false, false, 0);
    }
}