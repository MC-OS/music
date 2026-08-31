// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Native MTP: device manager registers AndroidDevice with the player. */

public class Music.Plugins.AndroidPlugin : Peas.ExtensionBase, Peas.Activatable {
    Music.Plugins.Interface plugins;
    public GLib.Object object { owned get; construct; }

    private AndroidDeviceManager? android_manager;
    private AndroidStreamer? streamer;

    public void activate () {
        message ("Activating Android MTP plugin (native)");

        Value value = Value (typeof (GLib.Object));
        get_property ("object", ref value);
        plugins = (Music.Plugins.Interface) value.get_object ();

        plugins.register_function (Music.Plugins.Interface.Hook.WINDOW, () => {
            android_manager = new AndroidDeviceManager ();

            /* Register playback backend for mtp-native:// URIs */
            streamer = new AndroidStreamer ();
            App.player.add_playback (streamer);
        });
    }

    public void deactivate () {
        if (android_manager != null) {
            android_manager.remove_all ();
            android_manager = null;
        }
        streamer = null;
    }

    public void update_state () {
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Music.Plugins.AndroidPlugin));
}
