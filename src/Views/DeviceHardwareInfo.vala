// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Hardware strip above stock DeviceSummaryWidget.
 *
 *   Top:    fancy name / model
 *   Left:   icon + click-to-rename name / space / capacity / battery / identity
 *   Middle: encrypt-backups switch + Back Up button
 *   Right:  OS version, security patch, Reset | Restore
 *   Strong dividers between columns and under the panel
 */

public class Music.DeviceHardwareInfo : Gtk.Grid {
    private Device device;

    private Gtk.Label fancy_label;
    private Gtk.Image device_image;

    private Gtk.Stack name_stack;
    private Gtk.Label name_label;
    private Gtk.Entry name_entry;

    private Gtk.Label space_label;
    private Gtk.Label capacity_label;
    private Gtk.Label battery_label;
    private Gtk.Label identity_key_label;
    private Gtk.Label identity_value_label;

    private Gtk.Switch encrypt_switch;
    private Gtk.Button backup_button;

    private Gtk.Label os_label;
    private Gtk.Label patch_label;
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

        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        // —— Top: fancy name / model ——
        fancy_label = new Gtk.Label ("");
        fancy_label.xalign = 0;
        fancy_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
        fancy_label.margin_start = 24;
        fancy_label.margin_top = 16;
        fancy_label.margin_end = 24;
        attach (fancy_label, 0, 0, 1, 1);

        // —— Left ——
        device_image = new Gtk.Image.from_gicon (device.get_icon (), Gtk.IconSize.DIALOG);
        device_image.pixel_size = 128;
        device_image.xalign = 0;

        name_label = new Gtk.Label (device.get_display_name ());
        name_label.xalign = 0;
        name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        name_label.tooltip_text = _("Click to rename");

        name_entry = new Gtk.Entry ();
        name_entry.text = device.get_display_name ();
        name_entry.width_chars = 20;

        name_stack = new Gtk.Stack ();
        name_stack.add_named (name_label, "label");
        name_stack.add_named (name_entry, "entry");
        name_stack.visible_child_name = "label";

        var name_event = new Gtk.EventBox ();
        name_event.visible_window = false;
        name_event.add (name_stack);
        name_event.button_press_event.connect (() => {
            if (name_stack.visible_child_name == "label") {
                begin_rename ();
                return true;
            }

            return false;
        });

        name_entry.activate.connect (commit_rename);
        name_entry.focus_out_event.connect (() => {
            commit_rename ();
            return false;
        });
        name_entry.key_press_event.connect ((e) => {
            if (e.keyval == Gdk.Key.Escape) {
                cancel_rename ();
                return true;
            }

            return false;
        });

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
        facts.attach (name_event, 0, 0, 1, 1);
        facts.attach (space_label, 0, 1, 1, 1);
        facts.attach (capacity_label, 0, 2, 1, 1);
        facts.attach (battery_label, 0, 3, 1, 1);
        facts.attach (identity_event, 0, 4, 1, 1);

        var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        left.pack_start (device_image, false, false, 0);
        left.pack_start (facts, false, false, 0);

        // —— Middle: encrypt + Back Up ——
        var encrypt_label = new Gtk.Label (_("Encrypt local backup"));
        encrypt_label.xalign = 0;

        encrypt_switch = new Gtk.Switch ();
        encrypt_switch.halign = Gtk.Align.START;
        encrypt_switch.tooltip_text = _("Encrypt backups with a password");

        var encrypt_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        encrypt_row.pack_start (encrypt_label, false, false, 0);
        encrypt_row.pack_start (encrypt_switch, false, false, 0);

        backup_button = new Gtk.Button.with_label (_("Back Up Now"));
        backup_button.halign = Gtk.Align.START;
        backup_button.clicked.connect (() => {
            NotificationManager.get_default ().show_alert (
                _("Back Up Now"),
                _("Device backup is not implemented for this device type yet.")
            );
        });

        var middle = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        middle.valign = Gtk.Align.CENTER;
        middle.margin_start = 8;
        middle.margin_end = 8;
        middle.pack_start (encrypt_row, false, false, 0);
        middle.pack_start (backup_button, false, false, 0);

        // —— Right: OS, patch, Reset | Restore ——
        os_label = new Gtk.Label ("");
        os_label.xalign = 0;
        os_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 0;
        patch_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        reset_button = new Gtk.Button.with_label (_("Reset"));
        restore_button = new Gtk.Button.with_label (_("Restore"));
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

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        actions.pack_start (reset_button, false, false, 0);
        actions.pack_start (restore_button, false, false, 0);

        var right = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        right.valign = Gtk.Align.START;
        right.pack_start (os_label, false, false, 0);
        right.pack_start (patch_label, false, false, 0);
        right.pack_start (actions, false, false, 0);

        // Noticeable vertical dividers between columns
        var vsep1 = new Gtk.Separator (Gtk.Orientation.VERTICAL);
        vsep1.margin_start = 16;
        vsep1.margin_end = 16;
        vsep1.width_request = 2;

        var vsep2 = new Gtk.Separator (Gtk.Orientation.VERTICAL);
        vsep2.margin_start = 16;
        vsep2.margin_end = 16;
        vsep2.width_request = 2;

        var columns = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        columns.margin = 24;
        columns.margin_top = 8;
        columns.pack_start (left, false, false, 0);
        columns.pack_start (vsep1, false, true, 0);
        columns.pack_start (middle, false, false, 0);
        columns.pack_start (vsep2, false, true, 0);
        columns.pack_start (right, false, false, 0);

        attach (columns, 0, 1, 1, 1);

        // Strong divider under the hardware panel (before summary)
        var bottom_sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        bottom_sep.margin_top = 16;
        bottom_sep.margin_bottom = 8;
        bottom_sep.margin_start = 12;
        bottom_sep.margin_end = 12;
        bottom_sep.height_request = 2;
        attach (bottom_sep, 0, 2, 1, 1);

        device.initialized.connect (() => {
            refresh ();
        });

        refresh ();
        show_all ();
    }

    private void begin_rename () {
        name_entry.text = device.get_display_name ();
        name_stack.visible_child_name = "entry";
        name_entry.grab_focus ();
        name_entry.select_region (0, -1);
    }

    private void commit_rename () {
        if (name_stack.visible_child_name != "entry") {
            return;
        }

        var text = name_entry.text.strip ();
        if (text.length > 0) {
            device.set_display_name (text);
            name_label.label = text;
        } else {
            name_label.label = device.get_display_name ();
        }

        name_stack.visible_child_name = "label";
    }

    private void cancel_rename () {
        name_entry.text = device.get_display_name ();
        name_stack.visible_child_name = "label";
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

        if (name_stack.visible_child_name == "label") {
            name_label.label = device.get_display_name ();
        }

        var cap = device.get_capacity ();
        var free = device.get_free_space ();
        if (cap > 0) {
            space_label.label = _("Space: %s").printf (GLib.format_size (cap));
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
