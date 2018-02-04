/**
* A view displaying a playlist, as a list of songs
*/
public class Noise.PlaylistView : View {
    public Playlist playlist { get; construct; }
    private MusicListView list_view { get; set; }

    public TreeViewSetup tvs { get; construct; }

    public PlaylistView (Playlist playlist, TreeViewSetup tvs) {
        Object (playlist: playlist, tvs: tvs);
    }

    construct {
        title = playlist.name;
        id = "local/playlist/" + playlist.id;
        category = "playlists";
        icon = playlist.icon;
        priority = 1;

        bool read_only = (playlist is StaticPlaylist) && (((StaticPlaylist)playlist).read_only);
        list_view = new MusicListView (tvs, read_only);
        list_view.set_compare_func (compare_func);
        list_view.set_search_func ((search, table, showing) => {
            showing.add_all (table);
        });
        list_view.show_in_playlist_menu.connect ((pl) => {
            return pl != playlist;
        });
        list_view.remove_request.connect ((media) => {
            if (playlist == App.main_window.library_manager.p_music) {
                var dialog = new RemoveFilesDialog (media);
                dialog.remove_media.connect ((delete_files) => {
                    App.main_window.library_manager.remove_medias (media, delete_files);
                });
            } else if (!read_only || playlist == App.player.queue_playlist) {
                playlist.remove_medias (media);
            }
        });
        list_view.set_media (playlist.medias);

        add (list_view);
        show_all ();

        playlist.media_added.connect (on_playlist_media_added);
        playlist.media_removed.connect (on_playlist_media_removed);
        playlist.cleared.connect (on_playlist_cleared);
        // playlist.request_play.connect (() => {
        //     App.player.clear_queue ();
        //     play_first_media (true);
        //     App.player.get_next (true);
        // });
    }

    private void update_badge () {
        if (playlist.show_badge) {
            badge = playlist.medias.size > 0 ? playlist.medias.size.to_string () : "";
        }
    }

    private void on_playlist_media_added (Gee.Collection<Media> to_add) {
        list_view.set_media (playlist.medias);
        update_badge ();
    }

    private void on_playlist_media_removed (Gee.Collection<Media> to_remove) {
        list_view.set_media (playlist.medias);
        update_badge ();
    }

    private void on_playlist_cleared () {
        list_view.set_media (new Gee.ArrayList<Media> ());
        update_badge ();
    }

    protected int compare_func (int column, Gtk.SortType dir, Media media_a, Media media_b, int a_pos, int b_pos) {
        if (playlist == App.player.queue_playlist) {
            return 0; // Display the queue in the order it actually is
        }

        return list_view.view_compare_func (column, dir, media_a, media_b, a_pos, b_pos);
    }

    public override bool filter (string search) {
        App.main_window.library_manager.search_medias (search);
        var result = App.main_window.library_manager.get_search_result ();

        var showing = new Gee.ArrayList<Media> ();
        foreach (var m in playlist.medias) {
            if (m in result) {
                showing.add (m);
            }
        }

        list_view.set_visible_media (showing);

        return showing.size > 0;
    }

    public override void update_alert (Granite.Widgets.AlertView alert) {
        alert.icon_name = "dialog-information";
        alert.title = _("No Songs");
        alert.description = _("To add songs to this playlist, use the <b>secondary click</b> on an item and choose <b>Add to Playlist</b>.");
    }
}
