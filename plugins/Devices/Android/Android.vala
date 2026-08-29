// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Native MTP test: no device UI registration yet — only terminal dumps. */

public class AndroidPlugin : Peas.ExtensionBase, Peas.Activatable {
    Music.Plugins.Interface plugins;
    public GLib.Object object { owned get; construct; }

    private MtpConsoleProbe? probe;
    private VolumeMonitor? volume_monitor;
    private uint idle_probe_id = 0;

    public void activate () {
        message ("Activating Android MTP plugin (native console probe)");

        Value value = Value (typeof (GLib.Object));
        get_property ("object", ref value);
        plugins = (Music.Plugins.Interface) value.get_object ();

        plugins.register_function (Music.Plugins.Interface.Hook.WINDOW, () => {
            probe = new MtpConsoleProbe ();
            volume_monitor = VolumeMonitor.get ();

            volume_monitor.volume_added.connect (on_volume_event);
            volume_monitor.mount_added.connect (on_mount_event);

            schedule_probe ("startup");
        });
    }

    public void deactivate () {
        if (idle_probe_id != 0) {
            Source.remove (idle_probe_id);
            idle_probe_id = 0;
        }

        if (volume_monitor != null) {
            volume_monitor.volume_added.disconnect (on_volume_event);
            volume_monitor.mount_added.disconnect (on_mount_event);
            volume_monitor = null;
        }

        probe = null;
    }

    public void update_state () {
    }

    private void on_volume_event (Volume volume) {
        schedule_probe ("volume_added: %s".printf (volume.get_name () ?? "?"));
    }

    private void on_mount_event (Mount mount) {
        schedule_probe ("mount_added: %s".printf (mount.get_name () ?? "?"));
    }

    private void schedule_probe (string reason) {
        if (probe == null) {
            return;
        }

        if (idle_probe_id != 0) {
            Source.remove (idle_probe_id);
        }

        var r = reason;
        idle_probe_id = Timeout.add (600, () => {
            idle_probe_id = 0;
            if (probe != null) {
                probe.probe_now (r);
            }

            return false;
        });
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (AndroidPlugin));
}
