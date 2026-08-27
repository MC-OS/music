// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Fancy name sits above the info panel (with a gap).
 * Capacity in a small bordered chip; battery uses system icon + % in center.
 */

public class Music.DeviceHardwareInfo : Gtk.Grid {
    private Device device;

    private Gtk.Label fancy_label;
    private Gtk.Image device_image;

    private Gtk.Stack name_stack;
    private Gtk.Label name_label;
    private Gtk.Entry name_entry;

    private Gtk.Frame capacity_frame;
    private Gtk.Label capacity_label;

    private Gtk.Image battery_icon;
    private Gtk.Label battery_pct_label;
    private Gtk.Widget battery_row;

    private Gtk.Label identity_key_label;
    private Gtk.Label identity_value_label;
    private Gtk.Widget identity_row;

    private Gtk.Label rom_label;
    private Gtk.Label os_label;
    private Gtk.Label patch_label;
    private Gtk.Button reset_button;

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
    private const string DEMO_ROM = "LFR 17.1";
    private const string DEMO_OS = "10";
    private const string DEMO_PATCH = "2020-05-01";
    private const int DEMO_BATTERY = 87;
    private const uint64 DEMO_CAPACITY = 32ULL * 1024 * 1024 * 1024;
    private const uint64 DEMO_FREE = 12ULL * 1024 * 1024 * 1024;

    public DeviceHardwareInfo (Device device) {
        this.device = device;

        hexpand = true;
        column_homogeneous = true;
        orientation = Gtk.Orientation.VERTICAL;

        fancy_label = new Gtk.Label ("");
        fancy_label.xalign = 0;
        fancy_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
        fancy_label.margin_start = 12;
        fancy_label.margin_end = 12;
        fancy_label.margin_top = 12;
        fancy_label.margin_bottom = 0;
        attach (fancy_label, 0, 0, 1, 1);

        var panel = new Gtk.Grid ();
        panel.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        panel.margin_top = 12;
        panel.hexpand = true;

        device_image = new Gtk.Image.from_gicon (device.get_panel_icon (), Gtk.IconSize.DIALOG);
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

        // Capacity: compact bordered chip
        capacity_label = new Gtk.Label ("");
        capacity_label.xalign = 0.5f;
        capacity_label.margin = 6;
        capacity_label.margin_start = 8;
        capacity_label.margin_end = 8;

        capacity_frame = new Gtk.Frame (null);
        capacity_frame.shadow_type = Gtk.ShadowType.IN;
        capacity_frame.halign = Gtk.Align.START;
        capacity_frame.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        capacity_frame.add (capacity_label);

        // Battery: system icon with percentage centered over it
        battery_icon = new Gtk.Image ();
        battery_icon.pixel_size = 48;

        battery_pct_label = new Gtk.Label ("");
        battery_pct_label.halign = Gtk.Align.CENTER;
        battery_pct_label.valign = Gtk.Align.CENTER;
        battery_pct_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        var battery_overlay = new Gtk.Overlay ();
        battery_overlay.halign = Gtk.Align.START;
        battery_overlay.add (battery_icon);
        battery_overlay.add_overlay (battery_pct_label);

        battery_row = battery_overlay;

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
        facts.row_spacing = 8;
        facts.attach (name_event, 0, 0, 1, 1);
        facts.attach (capacity_frame, 0, 1, 1, 1);
        facts.attach (battery_row, 0, 2, 1, 1);
        facts.attach (identity_row, 0, 3, 1, 1);

        var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        left.halign = Gtk.Align.START;
        left.pack_start (device_image, false, false, 0);
        left.pack_start (facts, false, false, 0);

        rom_label = new Gtk.Label ("");
        rom_label.xalign = 0;
        rom_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        os_label = new Gtk.Label ("");
        os_label.xalign = 0;
        os_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 0;
        patch_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        reset_button = new Gtk.Button.with_label (_("Reset"));
        reset_button.hexpand = true;
        reset_button.clicked.connect (() => {
            device.reset_device ();
        });

        var right = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        right.halign = Gtk.Align.END;
        right.valign = Gtk.Align.START;
        right.pack_start (rom_label, false, false, 0);
        right.pack_start (os_label, false, false, 0);
        right.pack_start (patch_label, false, false, 0);
        right.pack_start (reset_button, false, true, 0);

        var columns = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);
        columns.margin = 24;
        columns.hexpand = true;
        columns.pack_start (left, false, false, 0);
        columns.pack_end (right, true, true, 0);

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

    private string battery_icon_name (int percent) {
        // Prefer level icons when the theme provides them; fall back to classic names.
        int stepped = (percent.clamp (0, 100) / 10) * 10;
        var level = "battery-level-%d-symbolic".printf (stepped);

        var theme = Gtk.IconTheme.get_default ();
        if (theme.has_icon (level)) {
            return level;
        }

        if (percent >= 90) {
            return "battery-full-symbolic";
        } else if (percent >= 40) {
            return "battery-good-symbolic";
        } else if (percent >= 20) {
            return "battery-low-symbolic";
        } else if (percent >= 5) {
            return "battery-caution-symbolic";
        }

        return "battery-empty-symbolic";
    }

    private void apply_visibility () {
        fancy_label.visible = true;
        capacity_frame.visible = true;
        battery_row.visible = true;
        identity_row.visible = true;
        rom_label.visible = true;
        os_label.visible = true;
        patch_label.visible = true;
        reset_button.visible = device.can_reset ();
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

        device_image.set_from_gicon (device.get_panel_icon (), Gtk.IconSize.DIALOG);

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

        capacity_label.label = _("%s free of %s").printf (
            GLib.format_size (free),
            GLib.format_size (cap)
        );
        capacity_frame.tooltip_text = _("Capacity: %s · Free: %s").printf (
            GLib.format_size (cap),
            GLib.format_size (free)
        );

        int bat = device.get_battery_percent ();
        if (bat < 0) {
            bat = DEMO_BATTERY;
        }

        bat = bat.clamp (0, 100);
        battery_icon.set_from_icon_name (battery_icon_name (bat), Gtk.IconSize.DIALOG);
        battery_pct_label.label = "%d%%".printf (bat);
        battery_row.tooltip_text = _("Battery: %d%%").printf (bat);

        update_identity ();

        var rom = device.get_rom_name ();
        if (!has_text (rom)) {
            if (device.get_content_type ().has_prefix ("android")) {
                rom = DEMO_ROM;
            } else if (device.get_content_type ().has_prefix ("ipod")
                || device.get_content_type ().has_prefix ("iphone")) {
                rom = "iOS";
            } else {
                rom = "";
            }
        }

        rom_label.label = rom;

        var os = device.get_os_version ();
        if (!has_text (os)) {
            os = DEMO_OS;
        }

        if (device.get_content_type ().has_prefix ("android")) {
            os_label.label = _("Android %s").printf (os);
        } else {
            os_label.label = _("Version %s").printf (os);
        }

        var patch = device.get_security_patch ();
        if (!has_text (patch)) {
            patch = DEMO_PATCH;
        }

        patch_label.label = _("Security patch: %s").printf (patch);

        apply_visibility ();
    }
}
