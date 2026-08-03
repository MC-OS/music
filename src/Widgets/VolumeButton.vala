// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012-2026 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

public class Music.Widgets.VolumeButton : Gtk.MenuButton {
    private Gtk.Image icon;
    private Gtk.Scale slider;

    // Fixed: Added 'new' keyword to explicitly hide the inherited Gtk.MenuButton property
    private new Gtk.Popover popover;

    private double last_volume = 1.0;
    private bool is_muted = false;

    public VolumeButton () {
        Object ();
        
        // 1. Keep your original styling exactly as is
        this.relief = Gtk.ReliefStyle.NORMAL; 
        this.get_style_context ().add_class ("image-button");
        this.get_style_context ().add_class (Gtk.STYLE_CLASS_RAISED); // fixed typo check or keep original

        // 2. Setup the dynamic icon
        this.icon = new Gtk.Image.from_icon_name ("audio-volume-high-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        this.add (this.icon);

        // 3. Setup the clean vertical slider with 0.01 precision
        this.slider = new Gtk.Scale.with_range (Gtk.Orientation.VERTICAL, 0.0, 1.0, 0.01);
        this.slider.set_inverted (true); // Puts highest volume at the top
        this.slider.set_size_request (-1, 120); // Gives the slider physical height
        this.slider.draw_value = false; // Hides the raw text number
        this.slider.set_value (1.0); // Default starting volume

        // 4. Setup the popover and attach it to the button
        this.popover = new Gtk.Popover (this);
        
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        box.margin = 8;
        box.add (this.slider);
        box.show_all ();
        
        this.popover.add (box);
        this.set_popover (this.popover);

        // Prevent GTK's automatic outside-click dismissal so it stays pinned open on hover
        this.popover.modal = false;

        // 5. Hover-to-reveal: Pop open on mouse enter, close on leave using modern seat/device API
        this.enter_notify_event.connect ((event) => {
            this.popover.popup ();
            return false;
        });

        this.leave_notify_event.connect ((event) => {
            Gdk.Window window = this.get_window ();
            if (window != null) {
                var display = window.get_display ();
                var seat = display.get_default_seat ();
                if (seat != null) {
                    var pointer = seat.get_pointer ();
                    int x, y;
                    window.get_device_position (pointer, out x, out y, null);

                    Gtk.Allocation allocation;
                    this.get_allocation (out allocation);

                    // If pointer is outside the button boundaries, hide popover
                    if (x < 0 || x > allocation.width || y < 0 || y > allocation.height) {
                        this.popover.popdown ();
                    }
                }
            }
            return false;
        });

        // 6. Click behavior: Left click = Mute toggle
        this.button_press_event.connect ((event) => {
            if (event.button == 1) { // Left click = Mute toggle
                if (!is_muted) {
                    if (this.slider.get_value () > 0.0) {
                        last_volume = this.slider.get_value ();
                    }
                    is_muted = true;
                    this.slider.set_value (0.0);
                } else {
                    is_muted = false;
                    this.slider.set_value (last_volume > 0.0 ? last_volume : 0.5);
                }
                return true; // Handled
            }
            return false;
        });

        // 7. Wire up the audio connection and the dynamic icon logic
        this.slider.value_changed.connect (() => {
            double current_vol = this.slider.get_value ();
            
            if (current_vol > 0.0 && is_muted) {
                is_muted = false;
            } else if (current_vol == 0.0 && !is_muted) {
                is_muted = true;
            }

            // Your original connection
            App.player.volume = current_vol;
            
            // Trigger the icon change
            update_icon (current_vol);
        });
    }

    // Helper method to handle the dynamic icon switching
    private void update_icon (double volume) {
        string icon_name;
        
        if (volume == 0.0) {
            icon_name = "audio-volume-muted-symbolic";
        } else if (volume < 0.33) {
            icon_name = "audio-volume-low-symbolic";
        } else if (volume < 0.66) {
            icon_name = "audio-volume-medium-symbolic";
        } else {
            icon_name = "audio-volume-high-symbolic";
        }

        this.icon.set_from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
    }
}
