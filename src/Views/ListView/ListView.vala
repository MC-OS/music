// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012-2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Music authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Music. This permission is above and beyond the permissions granted
 * by the GPL license by which Music is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Victor Eduardo <victoreduardm@gmail.com>
 */

/**
 * Contains the column browser and list view.
 */
public class Music.ListView : Gtk.Box, ViewInterface {
    public signal void reordered ();

    public MusicListView list_view { get; construct set; }

    public ViewWrapper view_wrapper { get; construct set; }

    public uint n_media {
        get { return list_view.get_table ().size; }
    }

    // UI Properties

    public ListView (ViewWrapper view_wrapper, TreeViewSetup tvs) {
        Object (view_wrapper: view_wrapper,
                list_view: new MusicListView (view_wrapper, tvs));
    }

    construct {
        var list_scrolled = new Gtk.ScrolledWindow (null, null);
        list_scrolled.add (list_view);
        list_scrolled.expand = true;

        list_view.rows_reordered.connect (() => {
            reordered ();
        });

        list_view.import_requested.connect ((to_import) => {
            import_requested (to_import);
        });

        list_view.set_search_func (view_search_func);
        view_wrapper.library.search_finished.connect (() => { list_view.research_needed = true; });      
        add (list_scrolled);
    }

    /**
     * ContentView interface methods
     */

    public Playlist get_playlist () {
        return list_view.playlist;
    }

    public Gee.Collection<Media> get_media () {
        var media = new Gee.ArrayList<Media> ();
        media.add_all (list_view.get_table ());
        return media;
    }

    public Gee.Collection<Media> get_visible_media () {
        var media = new Gee.ArrayList<Media> ();
        media.add_all (list_view.get_visible_table ());
        return media;
    }

    public void set_as_current_list (int media_id) {
        list_view.set_as_current_list (view_wrapper.library.media_from_id (media_id));
    }

    public bool get_is_current_list () {
        return list_view.is_current_list;
    }

    public void add_media (Gee.Collection<Media> to_add) {
        list_view.add_media (to_add);
        list_view.research_needed = true;
        refilter ();
    }

    public void remove_media (Gee.Collection<Media> to_remove) {
        list_view.remove_media (to_remove);
        list_view.research_needed = true;
        refilter ();
    }

    public void set_media (Gee.Collection<Media> media) {
        list_view.set_media (media);
        list_view.research_needed = true;
    }

    public void update_media (Gee.Collection<Media> media) {
        refilter ();
    }

    public void refilter () {
        list_view.do_search ();
    }

    private void view_search_func (string search, Gee.ArrayList<Media> table, Gee.ArrayList<Media> showing) {
        var result = view_wrapper.library.get_search_result ();

        // If an external refiltering is going on, we cannot obey the column browser filter
        // because it wil be refreshed after this search based on the new 'showing' table
        // (populated by this method).

        if (result.size != view_wrapper.library.get_medias ().size) {
            foreach (var m in table) {              
                if (m in result) {
                    showing.add (m);
                }
            }
        } else {
            foreach (var m in table) {
                showing.add (m);
            }
        }

        // If nothing will be shown, display the "no media found" message.
        if (showing.size < 1 && search != "") {
            App.main_window.view_stack.show_alert ();
        }
    }
}
