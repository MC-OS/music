// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Hardware strip modeled on classic iTunes device Summary:
 *
 *   Left:  device icon + capacity / battery / serial cycle
 *   Right: OS version + patch, then Reset | Restore
 *   Below: Backups panel — encrypt option, Back Up Now | Restore Backup
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

    private Gtk.Button reset_button;
    private Gtk.Button restore_device_button;
    private Gtk.Button backup_now_button;
    private Gtk.Button restore_backup_button;
    private Gtk.CheckButton encrypt_backup_check;

    private enum IdentityMode {
        SERIAL,
        IMEI,
        MODEL
    }

    private IdentityMode mode = IdentityMode.SERIAL;

    public DeviceHardwareInfo (Device device) {
        this.device = device;

        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 0;
        margin = 24;
        margin_bottom = 8;
        halign = Gtk.Align.CENTER;

        // ── Top row: left facts + right software / restore ──
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

        // Right: OS + patch, then Reset | Restore (like Check for Update | Restore iPhone)
        os_label = new Gtk.Label ("");
        os_label.xalign = 0;
        os_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        patch_label = new Gtk.Label ("");
        patch_label.xalign = 0;
        patch_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        reset_button = new Gtk.Button.with_label (_("Reset"));
        restore_device_button = new Gtk.Button.with_label (_("Restore"));
        reset_button.clicked.connect (on_reset);
        restore_device_button.clicked.connect (on_restore_device);

        var software_actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        software_actions.pack_start (reset_button, false, false, 0);
        software_actions.pack_start (restore_device_button, false, false, 0);

        var right = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        right.valign = Gtk.Align.START;
        right.pack_start (os_label, false, false, 0);
        right.pack_start (patch_label, false, false, 0);
        right.pack_start (software_actions, false, false, 0);

        var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 48);
        top.pack_start (left, false, false, 0);
        top.pack_start (right, false, false, 0);

        attach (top, 0, 0, 1, 1);

        // ── Backups panel (middle of Summary, like iTunes) ──
        var backups_title = new Gtk.Label (_("<b>Backups</b>"));
        backups_title.use_markup = true;
        backups_title.xalign = 0;

        encrypt_backup_check = new Gtk.CheckButton.with_label (_("Encrypt local backup"));
        encrypt_backup_check.tooltip_text = _("Encrypt backups with a password");

        backup_now_button = new Gtk.Button.with_label (_("Back Up Now"));
        restore_backup_button = new Gtk.Button.with_label (_("Restore Backup"));
        backup_now_button.clicked.connect (on_backup_now);
        restore_backup_button.clicked.connect (on_restore_backup);

        var backup_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        backup_buttons.pack_start (backup_now_button, false, false, 0);
        backup_buttons.pack_start (restore_backup_button, false, false, 0);

        var backups_grid = new Gtk.Grid ();
        backups_grid.row_spacing = 8;
        backups_grid.column_spacing = 12;
        backups_grid.margin_top = 16;
        backups_grid.attach (backups_title, 0, 0, 2, 1);
        backups_grid.attach (encrypt_backup_check, 0, 1, 2, 1);
        backups_grid.attach (backup_buttons, 0, 2, 2, 1);

        attach (backups_grid, 0, 1, 1, 1);

        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.margin_top = 16;
        attach (sep, 0, 2, 1, 1);

        device.initialized.connect (() => {
            refresh ();
        });

        refresh ();
        show_all ();
        apply_visibility ();
    }

    private void on_backup_now () {
        NotificationManager.get_default ().show_alert (
            _("Back Up Now"),
            _("Device backup is not implemented for this device type yet.")
        );
    }

    private void on_restore_backup () {
        NotificationManager.get_default ().show_alert (
            _("Restore Backup"),
            _("Restoring from a backup is not implemented for this device type yet.")
        );
    }

    private void on_reset () {
        NotificationManager.get_default ().show_alert (
            _("Reset"),
            _("Device reset is not implemented for this device type yet.")
        );
    }

    private void on_restore_device () {
        NotificationManager.get_default ().show_alert (
            _("Restore"),
            _("Restoring this device is not implemented for this device type yet.")
        );
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
