/*-
 * Copyright (c) 2011       Scott Ringwelski <sgringwe@mtu.edu>
 *
 * Originaly Written by Scott Ringwelski for BeatBox Music Player
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

/* Merely a place holder for multiple pieces of information regarding
 * the current song playing. Mostly here because of dependence. */

using Gtk;

public class BeatBox.PreferencesWindow : Gtk.Window {
	BeatBox.LibraryManager _lm;
	BeatBox.LibraryWindow _lw;
	
	FileChooserButton fileChooser;
	
	CheckButton organizeFolders;
	CheckButton copyImportedMusic;
	CheckButton downloadNewPodcasts;
	
	Button lastfmLogin;
	Button saveChanges;
	
	string lastfm_token;
	
	public signal void changed(string folder);
	
	public PreferencesWindow (LibraryManager lm, LibraryWindow lw) {
	
		this._lm = lm;
		this._lw = lw;
		
		build_ui();
		
		_lm.file_operations_done.connect(fileOperationsDone);
	}
	
	void build_ui () {
	
		set_title("Preferences");

		// Window properties
		window_position = WindowPosition.CENTER;
		type_hint = Gdk.WindowTypeHint.DIALOG;
		modal = true;
		resizable = false;
		set_transient_for(_lw);
		set_size_request(400, 350);

		var content = new VBox(false, 10);
		var padding = new HBox(false, 10);
		
		var musicLabel = new Label("Music Folder Location");
		fileChooser = new FileChooserButton("Music Folder", FileChooserAction.SELECT_FOLDER);
		
		var managementLabel = new Label("Library Management");
		organizeFolders = new CheckButton.with_label("Keep Music folder organized");
		copyImportedMusic = new CheckButton.with_label("Copy files to Music folder when added to Library");
		downloadNewPodcasts = new CheckButton.with_label("Automatically download new Podcast episodes");
		
		var lastfmLabel = new Label("Last FM Integration");
		var lastfmInfo = new Granite.Widgets.WrapLabel("To allow for Last FM integration, you must give permission to BeatBox. You only need to do this once.");
		
		if(_lm.settings.getLastFMSessionKey() == null || _lm.settings.getLastFMSessionKey() == "")
			lastfmLogin = new Button.with_label("Enable Scrobbling");
		else {
			lastfmLogin = new Button.with_label("Scrobbling already Enabled");
			lastfmLogin.set_tooltip_text("Click to redo the Last FM Login Process");
		}
		
		saveChanges = new Button.with_label("Close");
		
		// fancy up the category labels
		musicLabel.xalign = 0.0f;
		managementLabel.xalign = 0.0f;
		lastfmLabel.xalign = 0.0f;
		musicLabel.set_markup("<b>Music Folder Location</b>");
		managementLabel.set_markup("<b>Library Management</b>");
		lastfmLabel.set_markup("<b>Last FM Integration</b>");
		
		// file chooser stuff
		fileChooser.set_current_folder(_lm.settings.getMusicFolder());
		
		if (_lm.doing_file_operations()) {
			fileChooser.set_sensitive(false);
			fileChooser.set_tooltip_text("You must wait until previous file operations finish before setting your music folder");
		}
		
		// initialize library management settings
		organizeFolders.set_active(_lm.settings.getUpdateFolderHierarchy());
		copyImportedMusic.set_active(_lm.settings.getCopyImportedMusic());
		downloadNewPodcasts.set_active(_lm.settings.getDownloadNewPodcasts());
		
		lastfmInfo.set_line_wrap(true);
		
		// Add save button
		var bottomButtons = new HButtonBox();
		bottomButtons.set_layout(ButtonBoxStyle.END);
		bottomButtons.pack_end(saveChanges, false, false, 0);
		
		// Pack all widgets
		content.pack_start(wrap_alignment(musicLabel, 10, 0, 0, 0), false, true, 0);
		content.pack_start(wrap_alignment(fileChooser, 0, 0, 0, 10), false, true, 0);
		content.pack_start(managementLabel, false, true, 0);
		content.pack_start(wrap_alignment(organizeFolders, 0, 0, 0, 10), false, true, 0);
		content.pack_start(wrap_alignment(copyImportedMusic, 0, 0, 0, 10), false, true, 0);
		content.pack_start(wrap_alignment(downloadNewPodcasts, 0, 0, 0, 10), false, true, 0);
		content.pack_start(lastfmLabel, false, true, 0);
		content.pack_start(wrap_alignment(lastfmInfo, 0, 0, 0, 10), false, true, 0);
		content.pack_start(wrap_alignment(lastfmLogin, 0, 0, 0, 10), false, true, 0);
		content.pack_end(bottomButtons, false, true, 10);
		
		padding.pack_start(content, true, true, 10);
		add(padding);
		
		lastfmLogin.clicked.connect(lastfmLoginClick);
		saveChanges.clicked.connect(saveClicked);
		
		show_all();
	}
	
	static Gtk.Alignment wrap_alignment (Gtk.Widget widget, int top, int right, int bottom, int left) {
	
		var alignment = new Gtk.Alignment(0.0f, 0.0f, 1.0f, 1.0f);
		alignment.top_padding = top;
		alignment.right_padding = right;
		alignment.bottom_padding = bottom;
		alignment.left_padding = left;
		
		alignment.add(widget);
		return alignment;
	}
	
	void lastfmLoginClick() {
	
		if(lastfmLogin.get_label() == "Enable Scrobbling" || lastfmLogin.get_label() == "Unsuccessful. Click to try again.") {
			lastfm_token = _lm.lfm.getToken();
			if(lastfm_token == null) {
				lastfmLogin.set_label("Unsuccessful. Click to try again.");
				stdout.printf("Could not get a token. check internet connection\n");
			}
			else {
				string auth_uri = "http://www.last.fm/api/auth/?api_key=" + LastFM.Core.api + "&token=" + lastfm_token;
				try {
					GLib.AppInfo.launch_default_for_uri (auth_uri, null);
				}
				catch(GLib.Error err) {
					stdout.printf("Could not open Last FM website to authorize: %s\n", err.message);
				}
				
				//set button text. we are done this time around. next time we get session key
				lastfmLogin.set_label("Complete login");
			}
		}
		else {
			if(lastfm_token == null) {
				lastfmLogin.set_label("Unsuccessful. Click to try again.");
				stdout.printf("Invalid token. Cannot continue\n");
			}
			else {
				var sk = _lm.lfm.getSessionKey(lastfm_token);
				if(sk == null) {
					lastfmLogin.set_label("Unsuccessful. Click to try again.");
					stdout.printf("Could not get Last FM session key\n");
				}
				else {
					_lm.settings.setLastFMSessionKey(sk);
					_lm.lfm.session_key = sk;
					_lm.lfm.logged_in();
					stdout.printf("Successfully obtained a sessionkey\n");
					lastfmLogin.set_sensitive(false);
					lastfmLogin.set_label("Success!");
				}
			}
		}
	}
		
	void saveClicked() {
	
		if(fileChooser.get_current_folder() != _lm.settings.getMusicFolder() || _lm.song_count() == 0) {
			changed(fileChooser.get_current_folder());
		}
		
		_lm.settings.setUpdateFolderHierarchy(organizeFolders.get_active());
		_lm.settings.setCopyImportedMusic(copyImportedMusic.get_active());
		_lm.settings.setDownloadNewPodcasts(downloadNewPodcasts.get_active());
		
		destroy();
	}

	void fileOperationsDone () {
	
		fileChooser.set_tooltip_text("");
		fileChooser.set_sensitive(true);
	}
}
