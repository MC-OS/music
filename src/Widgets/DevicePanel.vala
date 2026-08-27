// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Reusable section for the device / sync area — same structure as
 * DeviceHardwareInfo:
 *
 *   [ section title label ]   ← outside, H4
 *   ┌─────────────────────┐
 *   │  STYLE_CLASS_VIEW   │   ← panel body
 *   │   content box       │
 *   └─────────────────────┘
 *
 * Pack widgets into {@link content}. Use anywhere under the device view.
 */

public class Music.DevicePanel : Gtk.Grid {
    /** Section name shown above the panel (like the fancy model label). */
    public Gtk.Label title_label { get; private set; }

    /** VIEW-styled panel body (same class as the hardware info strip). */
    public Gtk.Grid panel { get; private set; }

    /** Vertical box inside {@link panel}; pack your controls here. */
    public Gtk.Box content { get; private set; }

    public DevicePanel (string title) {
        hexpand = true;
        orientation = Gtk.Orientation.VERTICAL;

        title_label = new Gtk.Label (title);
        title_label.xalign = 0;
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
        title_label.margin_bottom = 0;

        content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        content.margin = 12;
        content.hexpand = true;

        panel = new Gtk.Grid ();
        panel.hexpand = true;
        panel.margin_top = 6;
        panel.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        panel.attach (content, 0, 0, 1, 1);

        attach (title_label, 0, 0, 1, 1);
        attach (panel, 0, 1, 1, 1);
    }

    public void set_title (string title) {
        title_label.label = title;
    }
}
