/*-
 * Copyright (c) 2011-2012       Scott Ringwelski <sgringwe@mtu.edu>
 *
 * Originally Written by Scott Ringwelski for BeatBox Music Player
 * BeatBox Music Player: http://www.launchpad.net/beat-box
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

using Gtk;
using Gee;

public class Noise.SyncWarningDialog : Window {
	LibraryManager lm;
	LibraryWindow lw;
	Device d;
	Gee.LinkedList<Media> to_sync;
	Gee.LinkedList<Media> to_remove;
	
	private VBox content;
	private HBox padding;
	
	Button importMedias;
	Button sync;
	Button cancel;
	
	public SyncWarningDialog(LibraryManager lm, LibraryWindow lw, Device d, Gee.LinkedList<Media> to_sync, Gee.LinkedList<Media> removed) {
		this.lm = lm;
		this.lw = lw;
		this.d = d;
		this.to_sync = to_sync;
		this.to_remove = removed;

		// set the size based on saved gconf settings
		//this.window_position = WindowPosition.CENTER;
		this.type_hint = Gdk.WindowTypeHint.DIALOG;
		this.set_modal(true);
		this.set_transient_for(lw);
		this.destroy_with_parent = true;
		
		set_default_size(475, -1);
		resizable = false;
		
		content = new VBox(false, 10);
		padding = new HBox(false, 20);
		
		// initialize controls
		Image warning = new Image.from_stock(Gtk.Stock.DIALOG_ERROR, Gtk.IconSize.DIALOG);
		Label title = new Label("");
		Label info = new Label("");
		importMedias = new Button.with_label(_("Import media to Library"));
		sync = new Button.with_label(_("Continue Syncing"));
		cancel = new Button.with_label(_("Stop Syncing"));
		
		// pretty up labels
		title.xalign = 0.0f;
		info.xalign = 0.0f;

		info.set_line_wrap (true);
		var info_text = _("If you continue to sync, media will be removed from %s since they are not on the sync list. Would you like to import them to your library first?").printf ("<b>" + String.escape (d.getDisplayName ()) + "</b>");
		info.set_markup (info_text);

		// be a bit explicit to make translations better
		string title_text = "";
		if (to_remove.size > 1) {
			title_text = _("Sync will remove %i items from %s").printf (to_remove.size, d.getDisplayName ());
		}
		else {
			title_text = _("Sync will remove 1 item from %s").printf (d.getDisplayName ());
		}

		string MARKUP_TEMPLATE = "<span weight=\"bold\" size=\"larger\">%s</span>";		
		var title_string = MARKUP_TEMPLATE.printf (Markup.escape_text (title_text, -1));		
		title.set_markup (title_string);

		importMedias.set_sensitive(!lm.doing_file_operations());
		sync.set_sensitive(!lm.doing_file_operations());
		
		/* set up controls layout */
		HBox information = new HBox(false, 0);
		VBox information_text = new VBox(false, 0);
		information.pack_start(warning, false, false, 10);
		information_text.pack_start(title, false, true, 10);
		information_text.pack_start(info, false, true, 0);
		information.pack_start(information_text, true, true, 10);
		
		HButtonBox bottomButtons = new HButtonBox();
		bottomButtons.set_layout(ButtonBoxStyle.END);
		bottomButtons.pack_end(importMedias, false, false, 0);
		bottomButtons.pack_end(sync, false, false, 0);
		bottomButtons.pack_end(cancel, false, false, 10);
		bottomButtons.set_spacing(10);
		
		content.pack_start(information, false, true, 0);
		content.pack_start(bottomButtons, false, true, 10);
		
		padding.pack_start(content, true, true, 10);
		
		importMedias.clicked.connect(importMediasClicked);
		sync.clicked.connect(syncClicked);
		cancel.clicked.connect( () => { 
			this.destroy(); 
		});
		
		lm.file_operations_started.connect(file_operations_started);
		lm.file_operations_done.connect(file_operations_done);
		
		add(padding);
		show_all();
	}

	public void importMediasClicked() {
		d.transfer_to_library(to_remove);
		// TODO: After transfer, do sync
		
		this.destroy();
	}
	
	public void syncClicked() {
		d.sync_medias(to_sync);
		
		this.destroy();
	}
	
	public void file_operations_done() {
		importMedias.set_sensitive(true);
		sync.set_sensitive(true);
	}
	
	public void file_operations_started() {
		importMedias.set_sensitive(false);
		sync.set_sensitive(false);
	}
	
}
