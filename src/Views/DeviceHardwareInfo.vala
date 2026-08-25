// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Fancy name sits above the info panel (with a gap).
 * Panel: text left, OS + larger linked Reset|Restore on the right.
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
    private Gtk.Widget identity_row;

    private Gtk.Label os_label;
    private Gtk.Label patch_label;
    private Gtk.Button reset_button;
    private Gtk.Button restore_button;
    private Gtk.Widget actions_box;

    private enum IdentityMode {
        SERIAL,
        IMEI,
        MODEL
    }

    private IdentityMode mode = IdentityMode.SERIAL;

    private const string DEMO_MODEL = "Galaxy Tab A (2019)";
    private const string DEMO_NAME = "DJ’s Tablet";
    private const string DEMO_SERIAL = "R58M30DEMO01";
    private const string DEMO_IMEI = "359999999999999";
    private const string DEMO_MODEL_ID = "SM-T510";
    private const string DEMO_OS = "10";
    private const string DEMO_PATCH = "2020-05-01";
    private const int DEMO_BATTERY = 87;
    private const uint64 DEMO_CAPACITY = 32ULL * 1024 * 1024 * 1024;
    private const uint64 DEMO_FREE = 12ULL * 1024 * 1024 * 1024;

    public DeviceHardwareInfo (Device device) {
        this.device = device;

        orientation = Gtk.Orientation.VERTICAL;
        hexpand = true;

        // —— Fancy name ABOVE the panel, with a gap ——
        fancy_label = new Gtk.Label ("");
        fancy_label.xalign = 0;
        fancy_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
        fancy_label.margin_start = 24;
        fancy_label.margin_end = 24;
        fancy_label.margin_top = 16;
        fancy_label.margin_bottom = 0;
        attach (fancy_label, 0, 0, 1, 1);

        // —— Info panel (separate from fancy name) ——
        var panel = new Gtk.Grid ();
        panel.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        panel.margin_top = 12; // gap under fancy name
        panel.hexpand = true;

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
        name_event.key_press_event.connect ((e) => {
            if (e.keyval == Gdk.Key.Escape) {
                cancel_rename ();
                return true;
            }

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
        identity_row = identity_event;

        var facts = new Gtk.Grid ();
        facts.row_spacing = 4;
        facts.attach (name_event, 0, 0, 1, 1);
        facts.attach (space_label, 0, 1, 1, 1);
        facts.attach (capacity_label, 0, 2, 1, 1);
        facts.attach (battery_label, 0, 3, 1, 1);
        facts.attach (identity_row, 0, 4, 1, 1);

        // Text / facts pinned left
        var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        left.halign = Gtk.Align.START;
        left.pack_start (device_image, false, false, 0);
        left.pack_start (facts, false, false, 0);

        // Controls pinned right
        os_label = new Gtk.Label ("");
        os_label.xalign = 1;
        os_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 1;
        patch_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        reset_button = new Gtk.Button.with_label (_("Reset"));
        restore_button = new Gtk.Button.with_label (_("Restore"));
        reset_button.width_request = 100;
        restore_button.width_request = 100;
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

        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        actions.halign = Gtk.Align.END;
        actions.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        actions.pack_start (reset_button, false, false, 0);
        actions.pack_start (restore_button, false, false, 0);
        actions_box = actions;

        var right = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        right.halign = Gtk.Align.END;
        right.valign = Gtk.Align.START;
        right.pack_start (os_label, false, false, 0);
        right.pack_start (patch_label, false, false, 0);
        right.pack_start (actions_box, false, false, 0);

        var columns = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        columns.margin = 24;
        columns.hexpand = true;
        columns.pack_start (left, false, false, 0);
        columns.pack_end (right, false, false, 0);

        panel.attach (columns, 0, 0, 1, 1);
        attach (panel, 0, 1, 1, 1);

        device.initialized.connect (() => {
            refresh ();
        });

        refresh ();
        show_all ();
        apply_visibility ();
    }

    private void begin_rename () {
        name_entry.text = name_label.label;
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
        }

        name_stack.visible_child_name = "label";
    }

    private void cancel_rename () {
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

    private bool has_text (string? s) {
        return s != null && s.strip ().length > 0;
    }

    private void update_identity () {
        string serial = has_text (device.get_serial_number ()) ? device.get_serial_number () : DEMO_SERIAL;
        string imei = has_text (device.get_imei ()) ? device.get_imei () : DEMO_IMEI;
        string model = has_text (device.get_model_identifier ()) ? device.get_model_identifier () : DEMO_MODEL_ID;

        switch (mode) {
            case IdentityMode.SERIAL:
                identity_key_label.label = _("Serial Number:");
                identity_value_label.label = serial;
                break;
            case IdentityMode.IMEI:
                identity_key_label.label = _("IMEI:");
                identity_value_label.label = imei;
                break;
            case IdentityMode.MODEL:
                identity_key_label.label = _("Model:");
                identity_value_label.label = model;
                break;
        }
    }

    private void apply_visibility () {
        fancy_label.visible = true;
        space_label.visible = true;
        capacity_label.visible = true;
        battery_label.visible = true;
        identity_row.visible = true;
        os_label.visible = true;
        patch_label.visible = true;

        reset_button.visible = device.can_reset ();
        restore_button.visible = device.can_restore ();
        actions_box.visible = device.can_reset () || device.can_restore ();
    }

    public void refresh () {
        var model = device.get_model_identifier ();
        if (!has_text (model)) {
            model = device.get_fancy_description ();
        }

        if (!has_text (model)) {
            model = DEMO_MODEL;
        }

        fancy_label.label = model.strip ();

        device_image.set_from_gicon (device.get_icon (), Gtk.IconSize.DIALOG);

        var display = device.get_display_name ();
        if (!has_text (display) || display.down () == "mtp") {
            display = DEMO_NAME;
        }

        if (name_stack.visible_child_name == "label") {
            name_label.label = display;
        }

        var cap = device.get_capacity ();
        var free = device.get_free_space ();
        if (cap == 0) {
            cap = DEMO_CAPACITY;
            free = DEMO_FREE;
        }

        space_label.label = _("Space: %s").printf (GLib.format_size (cap));
        capacity_label.label = _("Capacity: %s (%s free)").printf (
            GLib.format_size (cap),
            GLib.format_size (free)
        );

        int bat = device.get_battery_percent ();
        if (bat < 0) {
            bat = DEMO_BATTERY;
        }

        battery_label.label = _("Battery: %d%%").printf (bat);

        update_identity ();

        var os = device.get_os_version ();
        if (!has_text (os)) {
            os = DEMO_OS;
        }

        if (device.get_content_type ().has_prefix ("android")) {
            os_label.label = _("Android %s").printf (os);
        } else {
            os_label.label = os;
        }

        var patch = device.get_security_patch ();
        if (!has_text (patch)) {
            patch = DEMO_PATCH;
        }

        patch_label.label = _("Security patch: %s").printf (patch);

        apply_visibility ();
    }
}
