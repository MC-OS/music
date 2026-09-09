// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Pure-GVFS CD plugin entry point.
 * Detect / list / play audio CDs through GIO (same path as the file manager).
 */

namespace Music.Plugins {
    public class CDRomPlugin : Peas.ExtensionBase, Peas.Activatable {

        Interface plugins;
        public GLib.Object object { owned get; construct; }
        CDRomDeviceManager cd_manager;

        public void activate () {
            message ("Activating CD Device plugin (GVFS)");

            Value value = Value (typeof (GLib.Object));
            get_property ("object", ref value);
            plugins = (Music.Plugins.Interface) value.get_object ();
            plugins.register_function (Interface.Hook.WINDOW, () => {
                cd_manager = new CDRomDeviceManager ();
            });
        }

        public void deactivate () {
            if (cd_manager != null) {
                cd_manager.remove_all ();
            }
        }

        public void update_state () {
            /*
             * Unfinished: the plugin currently does not need a refresh cycle.
             * This hook is kept for compatibility with the Peas activator API.
             */
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Peas.Activatable),
        typeof (Music.Plugins.CDRomPlugin)
    );
}
