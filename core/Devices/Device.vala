// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012-2018 elementary LLC. (https://elementary.io)
 */

public interface Music.Device : GLib.Object {
    public signal void initialized (Device d);
    public signal void device_unmounted ();
    public signal void infobar_message (string label, Gtk.MessageType message_type);
    public abstract uint64[] get_device_storage_info ();
    public abstract void set_device_storage_info (uint64[] info);
    public abstract bool start_initialization ();
    public abstract void finish_initialization ();
    public abstract string get_content_type ();
    public abstract string get_display_name ();
    public abstract string get_empty_device_title ();
    public abstract string get_empty_device_description ();
    public abstract void set_display_name (string name);
    public abstract string get_fancy_description ();
    public abstract string get_serial_number ();
    public abstract string get_imei ();
    public abstract string get_model_identifier ();
    public abstract int get_battery_percent ();
    public abstract string get_os_version ();
    public abstract string get_rom_name ();
    public abstract string get_security_patch ();
    public abstract void set_mount (Mount mount);
    public abstract Mount? get_mount ();
    public abstract string get_uri ();
    public abstract void set_icon (GLib.Icon icon);
    public abstract GLib.Icon get_icon ();
    public abstract uint64 get_capacity ();
    public abstract string get_fancy_capacity ();
    public abstract uint64 get_used_space ();
    public abstract uint64 get_free_space ();
    public abstract void unmount ();
    public abstract void eject ();
    public abstract void synchronize ();
    public abstract bool only_use_custom_view ();
    public abstract Gtk.Widget? get_custom_view ();
    public abstract bool read_only ();
    public abstract Library get_library ();

    public virtual GLib.Icon get_panel_icon () {
        return get_icon ();
    }

    public virtual bool can_recover () {
        return false;
    }

    public virtual string? get_last_backup_status () {
        return null;
    }

    /** True when a dedicated backup encryption password is already stored. */
    public virtual bool has_backup_password () {
        return false;
    }

    /**
     * Prompt to set or change the backup password.
     * Plugins may later also offer “use system password” on Linux.
     */
    public virtual void configure_backup_password () {
        infobar_message (
            _("Backup password setup is not implemented for this device type yet."),
            Gtk.MessageType.INFO
        );
    }

    public virtual void reset_device () {
        infobar_message (
            _("Device reset is not implemented for this device type yet."),
            Gtk.MessageType.INFO
        );
    }

    public virtual void backup_device (bool encrypt) {
        infobar_message (
            _("Device backup is not implemented for this device type yet."),
            Gtk.MessageType.INFO
        );
    }

    public virtual void restore_device () {
        infobar_message (
            _("Device restore is not implemented for this device type yet."),
            Gtk.MessageType.INFO
        );
    }

    public Gee.Collection<Music.Media> delete_doubles (Gee.Collection<Music.Media> source_list, Gee.Collection<Music.Media> to_remove) {
        var new_list = new Gee.LinkedList<Music.Media> ();
        foreach (var m in source_list) {
            if (m != null) {
                bool needed = true;
                foreach (var med in to_remove) {
                    if (med != null && med.title != null) {
                        if (med.album != null && m.album != null) {
                            if (med.title.down () == m.title.down () && med.artist.down () == m.artist.down () && med.album.down () == m.album.down ()) {
                                needed = false;
                                break;
                            }
                        } else {
                            if (med.title.down () == m.title.down () && med.artist.down () == m.artist.down ()) {
                                needed = false;
                                break;
                            }
                        }
                    }
                }
                if (needed == true) {
                    new_list.add (m);
                }
            }
        }

        return new_list;
    }

    public bool will_fit (Gee.Collection<Music.Media> list) {
        uint64 list_size = 0;
        foreach (var m in list) {
            list_size += m.file_size;
        }

        return get_capacity () > list_size;
    }

    public virtual string get_unique_identifier () {
        Mount? m = get_mount ();
        if (m != null) {
            string uuid = m.get_uuid ();
            File root = m.get_root ();
            string rv = "";
            debug ("uuid: %s\n", uuid);
            if (root != null && root.get_uri () != null) {
                rv += root.get_uri ();
            }
            if (uuid != null && uuid != "") {
                rv += ("/" + uuid);
            }

            return rv;
        } else {
            return get_uri ();
        }
    }
}
