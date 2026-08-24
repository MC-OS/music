// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Chunk 1: activate Android MTP device manager when the window is up. */

namespace Music.Plugins {
    public class AndroidPlugin : Peas.ExtensionBase, Peas.Activatable {
        Interface plugins;
        public GLib.Object object { owned get; construct; }
        AndroidDeviceManager? android_manager;

        public void activate () {
            message ("Activating Android MTP plugin (rewrite chunk 1)");

            Value value = Value (typeof (GLib.Object));
            get_property ("object", ref value);
            plugins = (Music.Plugins.Interface) value.get_object ();
            plugins.register_function (Interface.Hook.WINDOW, () => {
                android_manager = new AndroidDeviceManager ();
            });
        }

        public void deactivate () {
            if (android_manager != null) {
                android_manager.remove_all ();
                android_manager = null;
            }
        }

        public void update_state () {
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Music.Plugins.AndroidPlugin));
}
