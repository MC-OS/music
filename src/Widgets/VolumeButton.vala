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
    private new Gtk.Popover popover;

    private double last_volume = 1.0;
    private bool is_muted = false;
    private uint hide_timeout_id = 0;

    public VolumeButton () {
        Object ();
        
        // 1. Keep your original styling exactly as is
        this.relief = Gtk.ReliefStyle.NORMAL; 
        this.get_style_context ().add_class ("image-button");
        this.get_style_context ().add_class (Gtk.STYLE_CLASS_RAISED);

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
        this.popover.modal = false;

        // 5. Hover events for the button and slider
        this.enter_notify_event.connect ((event) => {
            cancel_hide_timeout ();
            this.popover.popup ();
            return false;
        });

        this.leave_notify_event.connect ((event) => {
            schedule_hide_check ();
            return false;
        });

        this.slider.enter_notify_event.connect ((event) => {
            cancel_hide_timeout ();
            return false;
        });

        this.slider.leave_notify_event.connect ((event) => {
            schedule_hide_check ();
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

            App.player.volume = current_vol;
            update_icon (current_vol);
        });
    }

    private void cancel_hide_timeout () {
        if (this.hide_timeout_id != 0) {
            GLib.Source.remove (this.hide_timeout_id);
            this.hide_timeout_id = 0;
        }
    }

    private void schedule_hide_check () {
        cancel_hide_timeout ();
        this.hide_timeout_id = GLib.Timeout.add (150, () => {
            this.hide_timeout_id = 0;

            Gdk.Window window = this.get_window ();
            if (window != null) {
                var display = window.get_display ();
                var seat = display.get_default_seat ();
                if (seat != null) {
                    var pointer = seat.get_pointer ();
                    int x, y;
                    window.get_device_position (pointer, out x, out y, null);

                    Gtk.Allocation btn_alloc;
                    this.get_allocation (out btn_alloc);

                    bool inside_button = (x >= 0 && x <= btn_alloc.width && y >= 0 && y <= btn_alloc.height);

                    bool inside_popover = false;
                    var pop_window = this.popover.get_window ();
                    if (pop_window != null) {
                        int pop_x, pop_y;
                        pop_window.get_device_position (pointer, out pop_x, out pop_y, null);
                        Gtk.Allocation pop_alloc;
                        this.popover.get_allocation (out pop_alloc);
                        inside_popover = (pop_x >= 0 && pop_x <= pop_alloc.width && pop_y >= 0 && pop_y <= pop_alloc.height);
                    }

                    if (!inside_button && !inside_popover) {
                        this.popover.popdown ();
                    }
                }
            }
            return false;
        });
    }

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
