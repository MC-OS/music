// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Device summary header inspired by classic iTunes device page
 * (layout only — not a visual clone).
 *
 * Left: device icon + capacity / battery / identity
 * Right: OS version + security patch
 * Identity line cycles Serial → IMEI → Model on click
 */

public class Music.Plugins.AndroidHardwareInfo : Gtk.Grid {
    private AndroidDevice device;

    private Gtk.Image device_image;
    private Gtk.Label name_label;
    private Gtk.Label capacity_label;
    private Gtk.Label battery_label;
    private Gtk.Label identity_key_label;
    private Gtk.Label identity_value_label;
    private Gtk.Label os_label;
    private Gtk.Label patch_label;

    private enum IdentityMode {
        SERIAL,
        IMEI,
        MODEL
    }

    private IdentityMode mode = IdentityMode.SERIAL;

    public AndroidHardwareInfo (AndroidDevice device) {
        this.device = device;
    
        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        // —— Left: product icon + facts ——
        device_image = new Gtk.Image.from_icon_name ("phone", Gtk.IconSize.DIALOG);
        device_image.pixel_size = 128;
        device_image.xalign = 0;

        name_label = new Gtk.Label (device.get_display_name ());
        name_label.xalign = 0;
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        capacity_label = new Gtk.Label ("");
        capacity_label.xalign = 0;

        battery_label = new Gtk.Label ("");
        battery_label.xalign = 0;

        identity_key_label = new Gtk.Label ("");
        identity_key_label.xalign = 0;
        identity_key_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        identity_value_label = new Gtk.Label ("");
        identity_value_label.xalign = 0;
        identity_value_label.selectable = true;

        var identity_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        identity_box.add (identity_key_label);
        identity_box.add (identity_value_label);

        var identity_event = new Gtk.EventBox ();
        identity_event.visible_window = false;
        identity_event.add (identity_box);
        identity_event.tooltip_text = _("Click to cycle Serial number, IMEI, and Model");
        identity_event.button_press_event.connect (() => {
            cycle_identity ();
            return true;
        });

        var facts = new Gtk.Grid ();
        facts.row_spacing = 4;
        facts.column_spacing = 8;
        facts.attach (name_label, 0, 0, 2, 1);
        facts.attach (capacity_label, 0, 1, 2, 1);
        facts.attach (battery_label, 0, 2, 2, 1);
        facts.attach (identity_event, 0, 3, 2, 1);

        var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        left.pack_start (device_image, false, false, 0);
        left.pack_start (facts, false, false, 0);

        // —— Right: software ——
        os_label = new Gtk.Label ("");
        os_label.xalign = 0;
        os_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 1;
        patch_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var right = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        right.pack_start (os_label, false, false, 0);
        right.pack_start (patch_label, false, false, 0);

        var main_info = new Gtk.Grid ();
        main_info.margin = 24;
        main_info.row_spacing = 4;
        main_info.column_spacing = 12;
        main_info.attach (left, 0, 0, 1, 1);
        main_info.attach (right, 1, 0, 1, 1);
        attach (main_info, 0, 0, 1, 1);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.margin_top = 12;
        attach (sep, 0, 1, 1, 1);

        refresh ();
        show_all ();
    }

    private void cycle_identity () {
        switch (mode) {
            case IdentityMode.SERIAL:
                mode = IdentityMode.IMEI;
                break;
            case IdentityMode.IMEI:
                mode = IdentityMode.MODEL;
                break;
            default:
                mode = IdentityMode.SERIAL;
                break;
        }

        update_identity ();
    }

    private void update_identity () {
        switch (mode) {
            case IdentityMode.SERIAL:
                identity_key_label.label = _("Serial Number:");
                identity_value_label.label = device.serial_number ?? _("Not available");
                break;
            case IdentityMode.IMEI:
                identity_key_label.label = _("IMEI:");
                identity_value_label.label = device.imei ?? _("Not available over MTP");
                break;
            case IdentityMode.MODEL:
                identity_key_label.label = _("Model:");
                identity_value_label.label = device.model_label ?? _("Not available");
                break;
        }
    }

    public void refresh () {
        name_label.label = device.get_display_name ();

        var cap = device.get_capacity ();
        var free = device.get_free_space ();
        if (cap > 0) {
            capacity_label.label = _("Capacity: %s (%s free)").printf (
                GLib.format_size (cap),
                GLib.format_size (free)
            );
        } else {
            capacity_label.label = _("Capacity: Not available");
        }

        if (device.battery_percent >= 0) {
            battery_label.label = _("Battery: %d%%").printf (device.battery_percent);
        } else {
            battery_label.label = _("Battery: —");
        }

        update_identity ();

        if (device.android_version != null) {
            os_label.label = _("Android %s").printf (device.android_version);
        } else if (device.device_version != null) {
            os_label.label = device.device_version;
        } else {
            os_label.label = _("Android");
        }

        if (device.security_patch != null) {
            patch_label.label = _("Security patch: %s").printf (device.security_patch);
        } else {
            patch_label.label = _("Security patch: Not available");
        }
    }
}
