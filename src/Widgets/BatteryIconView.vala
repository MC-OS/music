// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Reusable device hardware info panel displaying storage, battery, 
 * identity details (serial/IMEI/model), OS info, and reset controls.
 */

public class Music.BatteryIconView : Gtk.Bin {
    private Gtk.Image battery_icon;

    public BatteryIconView () {
        battery_icon = new Gtk.Image.from_icon_name ("battery-missing", Gtk.IconSize.DND);
        add (battery_icon);
        show_all ();
    }

    public void set_battery_level (int bat) {
        if (bat < 0) {
            this.visible = false;
            return;
        }

        this.visible = true;
        string battery_icon_name = "battery-missing";

        if (bat >= 90) {
            battery_icon_name = "battery-full";
        } else if (bat >= 40) {
            battery_icon_name = "battery-good";
        } else if (bat >= 20) {
            battery_icon_name = "battery-low";
        } else if (bat >= 5) {
            battery_icon_name = "battery-caution";
        } else if (bat >= 0) {
            battery_icon_name = "battery-empty";
        }

        var icon_theme = Gtk.IconTheme.get_default ();
        if (icon_theme.has_icon (battery_icon_name)) {
            battery_icon.set_from_icon_name (battery_icon_name, Gtk.IconSize.DND);
        }
    }
}