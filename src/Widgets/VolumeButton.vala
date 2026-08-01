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

    public VolumeButton () {
        Object ();
        
        // 1. Keep your original styling exactly as is
        this.relief = Gtk.ReliefStyle.NORMAL; 
        this.get_style_context ().add_class ("image-button");
        this.get_style_context ().add_class (Gtk.STYLE_CLASS_RAISED);

        // 2. Setup the dynamic icon
        this.icon = new Gtk.Image.from_icon_name ("audio-volume-high-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        this.add (this.icon);

        // 3. Setup the clean vertical slider
        this.slider = new Gtk.Scale.with_range (Gtk.Orientation.VERTICAL, 0.0, 1.0, 0.05);
        this.slider.set_inverted (true); // Puts highest volume at the top
        this.slider.set_size_request (-1, 120); // Gives the slider physical height
        this.slider.draw_value = false; // Hides the raw text number
        this.slider.set_value (1.0); // Default starting volume

        // 4. Setup the popover and attach it to the button
        var popover = new Gtk.Popover (this);
        popover.add (this.slider);
        
        // FIX: Ensure the slider is shown, but DO NOT force-show the popover container
        this.slider.show (); 
        
        this.set_popover (popover);

        // 5. Wire up the audio connection and the dynamic icon logic
        this.slider.value_changed.connect (() => {
            double current_vol = this.slider.get_value ();
            
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