// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Page layout:
 *   1) Hardware strip (upper panel)
 *   2) Stock summary — auto-sync, encrypt backup, Back Up Now, sync, storage bar
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

        orientation = Gtk.Orientation.VERTICAL;
        attach (infobar, 0, 0, 1, 1);

        var custom_view = device.get_custom_view ();
        if (custom_view != null && device.only_use_custom_view ()) {
            attach (custom_view, 0, 1, 1, 1);
        } else {
            var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep.height_request = 2;
            sep.margin_top = 4;
            sep.margin_bottom = 4;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.pack_start (hardware, false, false, 0);
            box.pack_start (sep, false, false, 0);
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
