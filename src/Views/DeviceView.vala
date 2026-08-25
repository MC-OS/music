// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Page layout:
 *   1) Hardware strip (upper panel)
 *   2) Backups band (middle of the view)
 *   3) Stock summary (lower panel)
 */

public class Music.DeviceView : Gtk.Grid {
    public Device device { get; construct; }
    public DevicePreferences preferences { get; construct; }

    public DeviceView (Music.Device device, DevicePreferences preferences) {
        Object (
            device: device,
            preferences: preferences
        );
    }

    construct {
        var infobar_label = new Gtk.Label ("");

        var infobar = new Gtk.InfoBar ();
        infobar.hexpand = true;
        infobar.add_button (_("Close"), 0);
        infobar.get_content_area ().add (infobar_label);

        var hardware = new DeviceHardwareInfo (device);
        var summary = new DeviceSummaryWidget (device, preferences);

        // —— Middle of the view: backups ——
        var backups_title = new Gtk.Label (_("<b>Backups</b>"));
        backups_title.use_markup = true;
        backups_title.xalign = 0;

        var encrypt_switch = new Gtk.Switch ();
        encrypt_switch.valign = Gtk.Align.CENTER;
        encrypt_switch.tooltip_text = _("Encrypt backups with a password");

        var encrypt_label = new Gtk.Label (_("Encrypt local backup"));
        encrypt_label.xalign = 0;

        var encrypt_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        encrypt_row.pack_start (encrypt_label, false, false, 0);
        encrypt_row.pack_start (encrypt_switch, false, false, 0);

        var backup_button = new Gtk.Button.with_label (_("Back Up Now"));
        backup_button.clicked.connect (() => {
            NotificationManager.get_default ().show_alert (
                _("Back Up Now"),
                _("Device backup is not implemented for this device type yet.")
            );
        });

        var backups_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        backups_box.margin = 24;
        backups_box.halign = Gtk.Align.CENTER;
        backups_box.pack_start (backups_title, false, false, 0);
        backups_box.pack_start (encrypt_row, false, false, 0);
        backups_box.pack_start (backup_button, false, false, 0);

        var backups_frame = new Gtk.Frame (null);
        backups_frame.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        backups_frame.add (backups_box);

        orientation = Gtk.Orientation.VERTICAL;
        attach (infobar, 0, 0, 1, 1);

        var custom_view = device.get_custom_view ();
        if (custom_view != null && device.only_use_custom_view ()) {
            attach (custom_view, 0, 1, 1, 1);
        } else {
            var sep_top = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep_top.height_request = 2;
            sep_top.margin_top = 4;
            sep_top.margin_bottom = 4;

            var sep_bottom = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep_bottom.height_request = 2;
            sep_bottom.margin_top = 4;
            sep_bottom.margin_bottom = 4;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.pack_start (hardware, false, false, 0);
            box.pack_start (sep_top, false, false, 0);
            box.pack_start (backups_frame, false, false, 0);
            box.pack_start (sep_bottom, false, false, 0);
            if (custom_view != null) {
                box.pack_start (custom_view, false, false, 0);
            }

            box.pack_start (summary, true, true, 0);
            attach (box, 0, 1, 1, 1);
        }

        show_all ();
        infobar.hide ();

        ulong connector = NotificationManager.get_default ().progress_canceled.connect (() => {
            if (device.get_library ().doing_file_operations ()) {
                NotificationManager.get_default ().show_alert (
                    _("Cancelling…"),
                    _("Device operation has been cancelled and will stop after this media.")
                );
            }
        });

        device.device_unmounted.connect (() => {
            device.disconnect (connector);
        });

        device.infobar_message.connect ((label, message_type) => {
            infobar_label.label = label;
            infobar.message_type = message_type;
            infobar.show_all ();
        });

        infobar.response.connect (() => {
            infobar.hide ();
        });

        if (preferences.sync_when_mounted) {
            summary.sync_clicked ();
        }
    }
}
