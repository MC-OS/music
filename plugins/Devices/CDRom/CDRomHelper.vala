// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/* Shared async import helper for audio CD tracks.
 *
 * Both import entry points (playlist right-click and sidebar right-click)
 * should call copy_track_async so the main loop stays responsive while the
 * optical drive spins. Blocking File.copy freezes the UI; copy_async with
 * a progress callback reports fraction without stalling.
 */

public class Music.Plugins.CDRomHelper : GLib.Object {
    /* Red Book: 2352 bytes/sector, 75 sectors/second. */
    private const uint BYTES_PER_SECTOR = 2352;
    private const uint SECTORS_PER_SEC = 75;

    /*
     * Copy one CD track from its GVFS cdda:// URI into dest_file.
     *
     * on_progress is called with the fraction of THIS track copied
     * (0.0 .. 1.0). Returns true on success.
     */
    public static async bool copy_track_async ( File source, File dest_file, owned FileProgressCallback? on_progress = null ) {
        try {
            yield source.copy_async ( dest_file, FileCopyFlags.OVERWRITE, Priority.DEFAULT, null, on_progress );

            return true;
        } catch (Error e) {
            warning ("[CD import] copy failed: %s", e.message);
            return false;
        }
    }

    /* Convenience: build the destination File for a track inside a folder. */
    public static File destination_for_track (File dest_dir, Media media) {
        string base_name = media.title;
        if (base_name == null || base_name == "") {
            base_name = _("Track %u").printf (media.track);
        }

        /* Strip characters that break filenames. */
        base_name = base_name.replace ("/", "-").replace ("\\", "-");

        return dest_dir.get_child (base_name + ".wav");
    }

    /* Estimated Red Book byte size for a track from its length in ms. */
    public static uint64 estimated_size (Media media) {
        double secs = media.length > 0 ? media.length / 1000.0 : 240.0;
        return (uint64) (secs * SECTORS_PER_SEC * BYTES_PER_SECTOR);
    }
}
