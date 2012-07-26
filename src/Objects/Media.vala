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

//using Gst;
using Gtk;

public class Noise.Media : GLib.Object {
	public enum MediaType {
		SONG,
		PODCAST,
		AUDIOBOOK,
		STATION,
		UNSPECIFIED
	}
	
	// TODO: Define more constants or even enum values
	public const int PREVIEW_ROWID = -2;

	//core info
	public string uri { get; set; default = ""; }
	public uint file_size { get; set; default = 0; }
	public int rowid { get; construct set; default = 0; }
	public MediaType mediatype { get; set; default = MediaType.SONG; }
	
	//tags
	public string title { get; set; default = _("Unknown Title"); }
	public string composer { get; set; default = ""; }
	public string artist { get; set; default = _("Unknown Artist"); }
	public string album_artist { get; set; default = ""; }
	public string album { get; set; default = _("Unknown Album"); }
	public string grouping { get; set; default = ""; }
	public string genre { get; set; default = ""; }
	public string comment { get; set; default = ""; }
	public uint year { get; set; default = 0; }
	public uint track { get; set; default = 0; }
	public uint track_count { get; set; default = 0; }
	public uint album_number { get; set; default = 0; }
	public uint album_count { get; set; default = 0; }
	public uint bitrate { get; set; default = 0; }
	public uint length { get; set; default = 0; }
	public uint bpm { get; set; default = 0; }
	public uint samplerate { get; set; default = 0; }
	public string lyrics { get; set; default = ""; }
	
	private uint _rating;
	public uint rating {
		get { return _rating; }
		set { 
			if(value >= 0 && value <= 5)
				_rating = value;
		}
	}
	
	public uint play_count { get; set; default = 0; }
	public uint skip_count { get; set; default = 0; }
	public uint date_added { get; set; default = 0; }
	public uint last_played { get; set; default = 0; }
	public uint last_modified { get; set; default = 0; }
	
	public string podcast_rss { get; set; default = ""; }
	public string podcast_url { get; set; default = ""; }
	public bool is_new_podcast { get; set; default = false; }
	public int resume_pos { get; set; default = 0; } // for podcasts and audiobooks
	public int podcast_date { get; set; default = 0; }
	
	private string _album_path;
	public bool has_embedded { get; set; default = false; }
	public bool is_video { get; set; default = false; }
	
	public bool isPreview { get; set; default = false; }
	public bool isTemporary { get; set; default = false; }
	public bool location_unknown { get; set; default = false; }
	
	public Gdk.Pixbuf? unique_status_image;
	public bool showIndicator { get; set; default = false; }
	public int pulseProgress { get; set; default = 0; }
	
	//core stuff
	public Media(string uri) {
		this.uri = uri;
	}
	
	//audioproperties
	public string pretty_length() {
		return TimeUtils.pretty_time_mins (length);
	}
	
	public string pretty_last_played() {
		return TimeUtils.pretty_timestamp_from_uint (last_played);
	}
	
	public string pretty_date_added() {
		return TimeUtils.pretty_timestamp_from_uint (date_added);
	}

	public string pretty_podcast_date() {
		return TimeUtils.pretty_timestamp_from_uint (podcast_date);
	}

	public Media copy() {
		Media rv = new Media(uri);
		rv.file_size = file_size;
		rv.rowid = rowid;
		rv.track = track;
		rv.track_count = track_count;
		rv.album_number = album_number;
		rv.album_count = album_count;
		rv.title = title;
		rv.artist = artist;
		rv.composer = composer;
		rv.album_artist = album_artist;
		rv.album = album;
		rv.genre = genre;
		rv.grouping = grouping;
		rv.comment = comment;
		rv.year = year;
		rv.bitrate = bitrate;
		rv.length = length;
		rv.samplerate = samplerate;
		rv.bpm = bpm;
		rv.rating = rating;
		rv.play_count = play_count;
		rv.skip_count = skip_count;
		rv.date_added = date_added;
		rv.last_played = last_played;
		rv.lyrics = lyrics; 
		rv.setAlbumArtPath(getAlbumArtPath());
		rv.isPreview = isPreview;
		rv.isTemporary = isTemporary;
		rv.last_modified = last_modified;
		rv.pulseProgress = pulseProgress;
		rv.showIndicator = showIndicator;
		rv.unique_status_image = unique_status_image;
		rv.location_unknown = location_unknown;
		
		// added for podcasts/audiobooks
		rv.mediatype = mediatype;
		rv.podcast_url = podcast_url;
		rv.podcast_rss = podcast_rss;
		rv.is_new_podcast = is_new_podcast;
		rv.resume_pos = resume_pos;
		rv.podcast_date = podcast_date;
		
		return rv;
	}
	
	public void setAlbumArtPath(string? path) {
		if(path != null)
			_album_path = path;
	}
	
	public string getAlbumArtPath() {
#if 0
		if(_album_path == "" || _album_path == "")
			return Icons.DEFAULT_ALBUM_ART.backup_filename;
		else
			return _album_path;
#endif
        if (_album_path == null)
            _album_path = "";
        return _album_path;
	}
	
	public string getArtistImagePath() {
		if(isTemporary == true || mediatype != Media.MediaType.SONG)
			return "";
		
		var path_file = File.new_for_uri(uri);
		if(!path_file.query_exists())
			return "";
		
		var path = path_file.get_path();
		return Path.build_path("/", path.substring(0, path.substring(0, path.last_index_of("/", 0)).last_index_of("/", 0)), "Artist.jpg");
	}
	
	public static Media from_track(string root, GPod.Track track) {
		Media rv = new Media("file://" + Path.build_path("/", root, GPod.iTunesDB.filename_ipod2fs(track.ipod_path)));
		
		rv.isTemporary = true;
		if(track.title != "") {			rv.title = track.title; }
		if(track.artist != "") {			rv.artist = track.artist; }
		if(track.albumartist != "") {		rv.album_artist = track.albumartist; }
		if(track.album != "") {			rv.album = track.album; }
		if(track.genre != "") {			rv.genre = track.genre; }
		if(track.comment != "") {			rv.comment = track.comment; }
		if(track.composer != "") {		rv.composer = track.composer; }
		if(track.grouping != "") {		rv.grouping = track.grouping; }
		rv.album_number = track.cd_nr;
		rv.album_count = track.cds;
		rv.track = track.track_nr;
		rv.track_count = track.tracks;
		rv.bitrate = track.bitrate;
		rv.year = track.year;
		rv.date_added = (int)track.time_added;
		rv.last_modified = (int)track.time_modified;
		rv.last_played = (int)track.time_played;
		rv.rating = track.rating * 20;
		rv.play_count = track.playcount;
		rv.bpm = track.BPM;
		rv.skip_count = track.skipcount;
		rv.length = track.tracklen  / 1000;
		rv.file_size = track.size;
		
		if(track.mediatype == GPod.MediaType.AUDIO)
			rv.mediatype = MediaType.SONG;
		else if(track.mediatype == GPod.MediaType.PODCAST) {
			rv.mediatype = MediaType.PODCAST;
			rv.is_video = false;
		}
		else if(track.mediatype == 0x00000006) {
			rv.mediatype = MediaType.PODCAST;
			rv.is_video = true;
		}
		else if(track.mediatype == GPod.MediaType.AUDIOBOOK)
			rv.mediatype = MediaType.AUDIOBOOK;
		
		rv.podcast_url = track.podcasturl;
		rv.is_new_podcast = track.mark_unplayed == 1;
		rv.resume_pos = (int)track.bookmark_time;
		rv.podcast_date = (int)track.time_released;
		
		if(rv.artist == "" && rv.album_artist != "")
			rv.artist = rv.album_artist;
		else if(rv.album_artist == "" && rv.artist != "")
			rv.album_artist = rv.artist;
		
		return rv;
	}
	
	public void update_track(ref unowned GPod.Track t) {
		if(t == null)
			return;
			
		if(title != "" && title != null) 			t.title = title;
		if(artist != "" && artist != null) 			t.artist = artist;
		if(album_artist != "" && album_artist != null) 	t.albumartist = album_artist;
		if(album != "" && album != null) 			t.album = album;
		if(genre != "" && genre != null) 			t.genre = genre;
		if(comment != "" && comment != null) 		t.comment = comment;
		if(composer != "" && composer != null) 		t.composer = composer;
		if(grouping != "" && grouping != null)		t.grouping = grouping;
		t.cd_nr = (int)album_number;
		t.cds = (int)album_count;
		t.track_nr = (int)track;
		t.tracks = (int)track_count;
		t.bitrate = (int)bitrate;
		t.year = (int)year;
		t.time_modified = (time_t)last_modified;
		t.time_played = (time_t)last_played;
		t.rating = rating * 20;
		t.playcount = play_count;
		t.recent_playcount = play_count;
		t.BPM = (uint16)bpm;
		t.skipcount = skip_count;
		t.tracklen = (int)length * 1000;
		t.size = file_size;
		t.mediatype = GPod.MediaType.AUDIO;
		t.lyrics_flag = 1;
		t.description = lyrics;
		
		if(mediatype == MediaType.SONG)
			t.mediatype = GPod.MediaType.AUDIO;
		else if(mediatype == MediaType.PODCAST) {
			if(is_video)
				t.mediatype = 0x00000006;
			else
				t.mediatype = GPod.MediaType.PODCAST;
		}
		else if(mediatype == MediaType.AUDIOBOOK)
			t.mediatype = GPod.MediaType.AUDIOBOOK;
		
		t.podcasturl = podcast_url;
		t.mark_unplayed = (play_count == 0) ? 1 : 0;
		t.bookmark_time = resume_pos;
		t.time_released = podcast_date;
		
		if(t.artist == "" && (t.albumartist != "" || t.albumartist != null))
			t.artist = t.albumartist;
		else if(t.albumartist == "" && (t.artist != "" || t.artist != null))
			t.albumartist = t.artist;
	}
	
	/* caller must set ipod_path */
	public GPod.Track track_from_media() {
		GPod.Track t = new GPod.Track();
		
		if(title != "" && title != null) 			t.title = title;
		if(artist != "" && artist != null) 			t.artist = artist;
		if(album_artist != "" && album_artist != null) 	t.albumartist = album_artist;
		if(album != "" && album != null) 			t.album = album;
		if(genre != "" && genre != null) 			t.genre = genre;
		if(comment != "" && comment != null) 		t.comment = comment;
		if(composer != "" && composer != null) 		t.composer = composer;
		if(grouping != "" && grouping != null)		t.grouping = grouping;
		t.cd_nr = (int)album_number;
		t.cds = (int)album_count;
		t.track_nr = (int)track;
		t.tracks = (int)track_count;
		t.bitrate = (int)bitrate;
		t.year = (int)year;
		t.time_modified = (time_t)last_modified;
		t.time_played = (time_t)last_played;
		t.rating = rating;
		t.playcount = play_count;
		t.recent_playcount = play_count;
		t.BPM = (uint16)bpm;
		t.skipcount = skip_count;
		t.tracklen = (int)length * 1000;
		t.size = file_size;
		t.mediatype = GPod.MediaType.AUDIO;
		t.lyrics_flag = 1;
		t.description = lyrics;
		
		if(mediatype == MediaType.SONG)
			t.mediatype = GPod.MediaType.AUDIO;
		else if(mediatype == MediaType.PODCAST) {
			if(is_video)
				t.mediatype = 0x00000006;
			else
				t.mediatype = GPod.MediaType.PODCAST;
		}
		else if(mediatype == MediaType.AUDIOBOOK)
			t.mediatype = GPod.MediaType.AUDIOBOOK;
		
		t.podcasturl = podcast_url;
		t.mark_unplayed = (play_count == 0) ? 1 : 0;
		t.bookmark_time = resume_pos;
		t.time_released = podcast_date;
		
		if(t.artist == "" && (t.albumartist != "" || t.albumartist != null))
			t.artist = t.albumartist;
		else if(t.albumartist == "" && (t.artist != "" || t.artist != null))
			t.albumartist = t.artist;
		
		return t;
	}
}
