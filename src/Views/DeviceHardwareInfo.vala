// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Hardware info strip above the stock DeviceSummaryWidget.
 * Used for all devices; empty fields are hidden.
 */

public class Music.DeviceHardwareInfo : Gtk.Grid {
    private Device device;

    private Gtk.Image device_image;
    private Gtk.Label name_label;
    private Gtk.Label capacity_label;
    private Gtk.Label battery_label;
    private Gtk.Label identity_key_label;
    private Gtk.Label identity_value_label;
    private Gtk.Widget identity_row;
    private Gtk.Label os_label;
    private Gtk.Label patch_label;
    private Gtk.Widget software_box;

    private Gtk.Button backup_button;
    private Gtk.Button reset_button;
    private Gtk.Button restore_button;

    private enum IdentityMode {
        SERIAL,
        IMEI,
        MODEL
    }

    private IdentityMode mode = IdentityMode.SERIAL;

    public DeviceHardwareInfo (Device device) {
        this.device = device;

        column_spacing = 24;
        row_spacing = 4;
        margin = 24;
        margin_bottom = 8;
        halign = Gtk.Align.CENTER;

        device_image = new Gtk.Image.from_gicon (device.get_icon (), Gtk.IconSize.DIALOG);
        device_image.pixel_size = 96;
        device_image.valign = Gtk.Align.START;

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
        identity_row = identity_event;

        var facts = new Gtk.Grid ();
        facts.row_spacing = 4;
        facts.attach (name_label, 0, 0, 1, 1);
        facts.attach (capacity_label, 0, 1, 1, 1);
        facts.attach (battery_label, 0, 2, 1, 1);
        facts.attach (identity_row, 0, 3, 1, 1);

        var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        left.pack_start (device_image, false, false, 0);
        left.pack_start (facts, false, false, 0);

        os_label = new Gtk.Label ("");
        os_label.xalign = 0.5f;
        os_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 0.5f;
        patch_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var software = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        software.valign = Gtk.Align.CENTER;
        software.pack_start (os_label, false, false, 0);
        software.pack_start (patch_label, false, false, 0);
        software_box = software;

        backup_button = new Gtk.Button.with_label (_("Backup"));
        reset_button = new Gtk.Button.with_label (_("Reset"));
        restore_button = new Gtk.Button.with_label (_("Restore"));
        backup_button.clicked.connect (() => {
            NotificationManager.get_default ().show_alert (
                _("Backup"),
                _("Device backup is not implemented for this device type yet.")
            );
        });
        reset_button.clicked.connect (() => {
            NotificationManager.get_default ().show_alert (
                _("Reset"),
                _("Device reset is not implemented for this device type yet.")
            );
        });
        restore_button.clicked.connect (() => {
            NotificationManager.get_default ().show_alert (
                _("Restore"),
                _("Device restore is not implemented for this device type yet.")
            );
        });

        var actions = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        actions.valign = Gtk.Align.START;
        actions.pack_start (backup_button, false, false, 0);
        actions.pack_start (reset_button, false, false, 0);
        actions.pack_start (restore_button, false, false, 0);

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 32);
        row.pack_start (left, false, false, 0);
        row.pack_start (software_box, false, false, 0);
        row.pack_end (actions, false, false, 0);

        attach (row, 0, 0, 1, 1);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.margin_top = 12;
        attach (sep, 0, 1, 1, 1);

        device.initialized.connect (() => {
            refresh ();
        });

        refresh ();
        show_all ();
        apply_visibility ();
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

    private void apply_visibility () {
        capacity_label.visible = device.get_capacity () > 0;
        battery_label.visible = device.get_battery_percent () >= 0;

        bool any_id = device.get_serial_number () != null
            || device.get_imei () != null
            || device.get_model_identifier () != null;
        identity_row.visible = any_id;

        os_label.visible = device.get_os_version () != null;
        patch_label.visible = device.get_security_patch () != null;
        software_box.visible = os_label.visible || patch_label.visible;
    }

    public void refresh () {
        device_image.set_from_gicon (device.get_icon (), Gtk.IconSize.DIALOG);
        name_label.label = device.get_display_name ();

        var cap = device.get_capacity ();
        var free = device.get_free_space ();
        if (cap > 0) {
            capacity_label.label = _("Capacity: %s (%s free)").printf (
                GLib.format_size (cap),
                GLib.format_size (free)
            );
        } else {
            capacity_label.label = "";
        }

        int bat = device.get_battery_percent ();
        if (bat >= 0) {
            battery_label.label = _("Battery: %d%%").printf (bat);
        } else {
            battery_label.label = "";
        }

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

        update_identity ();
        apply_visibility ();
    }
}
