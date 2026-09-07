// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Pure-GVFS CD plugin entry point.
 * Detect / list / play audio CDs through GIO (same path as the file manager).
 */

namespace Music.Plugins {
    public class CDPlugin : Peas.ExtensionBase, Peas.Activatable {

        Interface plugins;
        public GLib.Object object { owned get; construct; }
        CDDeviceManager cd_manager;

        public void activate () {
            message ("Activating CD Device plugin (GVFS)");

            Value value = Value (typeof (GLib.Object));
            get_property ("object", ref value);
            plugins = (Music.Plugins.Interface) value.get_object ();
            plugins.register_function (Interface.Hook.WINDOW, () => {
                cd_manager = new CDDeviceManager ();
            });
        }

        public void deactivate () {
            if (cd_manager != null) {
                cd_manager.remove_all ();
            }
        }

        public void update_state () {
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Peas.Activatable),
        typeof (Music.Plugins.CDPlugin)
    );
}
