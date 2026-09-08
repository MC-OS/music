// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* CD burn UI placeholder.
 *
 * Returned from CDDevice.get_custom_view() and stacked below the normal
 * DeviceSummaryWidget + library list by DeviceView (row 1). This is where
 * the burn-CD interface will live later; for now it is an empty container
 * so the slot is reserved without hiding the track list.
 */

public class Music.Plugins.CDView : Gtk.Box {
    private CDLibrary library;
    private CDDevice device;

    public CDView (CDDevice device, CDLibrary library) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        this.device = device;
        this.library = library;

        // Burn-CD UI goes here. Keep this box empty for now so it does not
        // interfere with the library list rendered above it by DeviceView.
        show_all ();
    }
}
