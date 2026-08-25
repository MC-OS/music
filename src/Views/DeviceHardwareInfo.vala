// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Hardware strip — same layout as the earlier AndroidHardwareInfo
 * the user approved, moved into core for all devices.
 *
 * Top:   plain model / fancy name
 * Left:  device icon + name / space / capacity / battery / identity
 * Right: OS version + security patch
 */

public class Music.DeviceHardwareInfo : Gtk.Grid {
    private Device device;

    private Gtk.Label fancy_label;
    private Gtk.Image device_image;
    private Gtk.Label name_label;
    private Gtk.Label space_label;
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

    public DeviceHardwareInfo (Device device) {
        this.device = device;

        fancy_label = new Gtk.Label ("");
        fancy_label.xalign = 0;
        fancy_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
        attach (fancy_label, 0, 0, 1, 1);

        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        // —— Left: product icon + facts ——
        device_image = new Gtk.Image.from_gicon (device.get_icon (), Gtk.IconSize.DIALOG);
        device_image.pixel_size = 128;
        device_image.xalign = 0;

        name_label = new Gtk.Label (device.get_display_name ());
        name_label.xalign = 0;
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        space_label = new Gtk.Label ("");
        space_label.xalign = 0;

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
        facts.attach (space_label, 0, 1, 2, 1);
        facts.attach (capacity_label, 0, 2, 2, 1);
        facts.attach (battery_label, 0, 3, 2, 1);
        facts.attach (identity_event, 0, 4, 2, 1);

        var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        left.pack_start (device_image, false, false, 0);
        left.pack_start (facts, false, false, 0);

        // —— Right: software ——
        os_label = new Gtk.Label ("");
        os_label.xalign = 0;
        os_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 0;
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
        attach (main_info, 0, 1, 1, 1);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.margin_top = 12;
        sep.margin_bottom = 12;
        attach (sep, 0, 2, 1, 1);

        device.initialized.connect (() => {
            refresh ();
        });

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
                identity_value_label.label = device.get_serial_number () ?? _("Not available");
                break;
            case IdentityMode.IMEI:
                identity_key_label.label = _("IMEI:");
                identity_value_label.label = device.get_imei () ?? _("Not available");
                break;
            case IdentityMode.MODEL:
                identity_key_label.label = _("Model:");
                identity_value_label.label = device.get_model_identifier () ?? _("Not available");
                break;
        }
    }

    public void refresh () {
        var model = device.get_model_identifier ();
        if (model == null || model.strip ().length == 0) {
            var fancy = device.get_fancy_description ();
            model = (fancy != null && fancy.strip ().length > 0) ? fancy.strip () : null;
        }

        fancy_label.label = model ?? "";
        fancy_label.visible = model != null;

        device_image.set_from_gicon (device.get_icon (), Gtk.IconSize.DIALOG);
        name_label.label = device.get_display_name ();

        var cap = device.get_capacity ();
        var free = device.get_free_space ();
        if (cap > 0) {
            space_label.label = _("Space: %s").printf (
                GLib.format_size (cap)
            );

            capacity_label.label = _("Capacity: %s (%s free)").printf (
                GLib.format_size (cap),
                GLib.format_size (free)
            );
        } else {
            space_label.label = _("Space: Not available");
            capacity_label.label = _("Capacity: Not available");
        }

        int bat = device.get_battery_percent ();
        if (bat >= 0) {
            battery_label.label = _("Battery: %d%%").printf (bat);
        } else {
            battery_label.label = _("Battery: —");
        }

        update_identity ();

        var os = device.get_os_version ();
        if (os != null) {
            if (device.get_content_type ().has_prefix ("android")) {
                os_label.label = _("Android %s").printf (os);
            } else {
                os_label.label = os;
            }
        } else {
            os_label.label = "";
        }

        var patch = device.get_security_patch ();
        if (patch != null) {
            patch_label.label = _("Security patch: %s").printf (patch);
        } else {
            patch_label.label = "";
        }
    }
}
