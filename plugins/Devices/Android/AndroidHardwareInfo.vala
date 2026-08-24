// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Hardware info strip above stock DeviceSummaryWidget (iTunes-style).
 * Click identity row cycles: Serial → IMEI → Model.
 */

public class Music.Plugins.AndroidHardwareInfo : Gtk.Grid {
    private AndroidDevice device;
    private Gtk.Label identity_title;
    private Gtk.Label identity_value;
    private Gtk.Label version_value;
    private Gtk.Label patch_value;
    private Gtk.Image battery_icon;
    private Gtk.Label battery_label;

    private enum IdentityMode {
        SERIAL,
        IMEI,
        MODEL
    }

    private IdentityMode mode = IdentityMode.SERIAL;

    public AndroidHardwareInfo (AndroidDevice device) {
        this.device = device;

        column_spacing = 12;
        row_spacing = 6;
        margin_start = 24;
        margin_end = 24;
        margin_top = 16;
        margin_bottom = 0;
        halign = Gtk.Align.CENTER;

        // Battery (placeholder / real % when MTP reports it)
        battery_icon = new Gtk.Image.from_icon_name ("battery-good-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        battery_label = new Gtk.Label ("");
        battery_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var battery_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        battery_box.valign = Gtk.Align.CENTER;
        battery_box.add (battery_icon);
        battery_box.add (battery_label);

        // Identity: click to cycle Serial / IMEI / Model
        identity_title = new Gtk.Label ("");
        identity_title.xalign = 0;
        identity_title.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        identity_value = new Gtk.Label ("");
        identity_value.xalign = 0;
        identity_value.selectable = true;
        identity_value.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var identity_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        identity_box.add (identity_title);
        identity_box.add (identity_value);

        var identity_event = new Gtk.EventBox ();
        identity_event.visible_window = false;
        identity_event.add (identity_box);
        identity_event.button_press_event.connect (() => {
            cycle_identity ();
            return true;
        });
        identity_event.tooltip_text = _("Click to cycle Serial, IMEI, and Model");

        // Android version + security patch (best-effort over MTP)
        var version_title = new Gtk.Label (_("Android version"));
        version_title.xalign = 0;
        version_title.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        version_value = new Gtk.Label ("");
        version_value.xalign = 0;

        var patch_title = new Gtk.Label (_("Security patch"));
        patch_title.xalign = 0;
        patch_title.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        patch_value = new Gtk.Label ("");
        patch_value.xalign = 0;

        var meta_grid = new Gtk.Grid ();
        meta_grid.column_spacing = 24;
        meta_grid.row_spacing = 4;
        meta_grid.attach (version_title, 0, 0);
        meta_grid.attach (version_value, 0, 1);
        meta_grid.attach (patch_title, 1, 0);
        meta_grid.attach (patch_value, 1, 1);

        attach (battery_box, 0, 0, 1, 2);
        attach (identity_event, 1, 0, 1, 1);
        attach (meta_grid, 1, 1, 1, 1);

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
            case IdentityMode.MODEL:
            default:
                mode = IdentityMode.SERIAL;
                break;
        }

        update_identity_labels ();
    }

    private void update_identity_labels () {
        switch (mode) {
            case IdentityMode.SERIAL:
                identity_title.label = _("Serial number");
                identity_value.label = device.serial_number ?? _("Not available");
                break;
            case IdentityMode.IMEI:
                identity_title.label = _("IMEI");
                identity_value.label = device.imei ?? _("Not available over MTP");
                break;
            case IdentityMode.MODEL:
                identity_title.label = _("Model");
                identity_value.label = device.model_label ?? _("Not available");
                break;
        }
    }

    public void refresh () {
        update_identity_labels ();

        version_value.label = device.android_version ?? (device.device_version ?? _("Not available"));
        patch_value.label = device.security_patch ?? _("Not available");

        if (device.battery_percent >= 0) {
            battery_label.label = "%d%%".printf (device.battery_percent);
            battery_icon.icon_name = battery_icon_name (device.battery_percent);
            battery_box_tooltip (device.battery_percent);
        } else {
            battery_label.label = _("—");
            battery_icon.icon_name = "battery-missing-symbolic";
            battery_icon.tooltip_text = _("Battery level not reported over MTP");
            battery_label.tooltip_text = battery_icon.tooltip_text;
        }
    }

    private void battery_box_tooltip (int percent) {
        var t = _("Battery %d%%").printf (percent);
        battery_icon.tooltip_text = t;
        battery_label.tooltip_text = t;
    }

    private string battery_icon_name (int percent) {
        if (percent >= 90) {
            return "battery-full-symbolic";
        }
        if (percent >= 60) {
            return "battery-good-symbolic";
        }
        if (percent >= 30) {
            return "battery-low-symbolic";
        }
        if (percent >= 10) {
            return "battery-caution-symbolic";
        }

        return "battery-empty-symbolic";
    }
}
