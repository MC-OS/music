// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* CD/DVD plugin entry point. */

public class Music.Plugins.CDPlugin : Peas.ExtensionBase, Peas.Activatable {
    Music.Plugins.Interface plugins;
    public GLib.Object object { owned get; construct; }

    private CDDeviceManager? cd_manager;

    public void activate () {
        message ("Activating CD/DVD plugin");

        Value value = Value (typeof (GLib.Object));
        get_property ("object", ref value);
        plugins = (Music.Plugins.Interface) value.get_object ();

        plugins.register_function (Music.Plugins.Interface.Hook.WINDOW, () => {
            cd_manager = new CDDeviceManager ();
        });
    }

    public void deactivate () {
        if (cd_manager != null) {
            cd_manager.remove_all ();
            cd_manager = null;
        }
    }

    public void update_state () {
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Music.Plugins.CDPlugin));
}
