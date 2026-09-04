/* libmtp bindings — compact handles, no Vala ownership transfer */
[CCode (cheader_filename = "libmtp.h", cprefix = "LIBMTP_", lower_case_cprefix = "LIBMTP_")]
namespace Mtp {

    /* Progress callback used by Get_*_To_File / Send_*_From_File family.
     * Return 0 to continue, non-zero to cancel the transfer. */
    [CCode (cname = "LIBMTP_progressfunc_t", has_target = false)]
    public delegate int ProgressFunc (uint64 sent, uint64 total, void* data);

    /* Handler callbacks for streaming transfers without a local file. */
    [CCode (cname = "MTPDataGetFunc", has_target = false)]
    public delegate uint16 DataGetFunc (void* params, void* priv, uint32 wantlen, uint8* data, out uint32 gotlen);

    [CCode (cname = "MTPDataPutFunc", has_target = false)]
    public delegate uint16 DataPutFunc (void* params, void* priv, uint32 sendlen, uint8* data, out uint32 putlen);

    [CCode (cname = "LIBMTP_devicestorage_t", free_function = "", unref_function = "", has_type_id = false, copy_function = "")]
    [Compact]
    public class Storage {
        public uint32 id;
        public uint64 MaxCapacity;
        public uint64 FreeSpaceInBytes;
        public unowned string? StorageDescription;
        public unowned string? VolumeIdentifier;
        public unowned Storage? next;
    }

    [CCode (cname = "LIBMTP_mtpdevice_t", free_function = "", unref_function = "", has_type_id = false, copy_function = "")]
    [Compact]
    public class Device {
        public unowned Storage? storage;

        [CCode (cname = "LIBMTP_Get_Friendlyname")]
        public unowned string? get_friendly_name ();

        [CCode (cname = "LIBMTP_Set_Friendlyname")]
        public int set_friendly_name (string name);

        [CCode (cname = "LIBMTP_Get_Modelname")]
        public unowned string? get_model_name ();

        [CCode (cname = "LIBMTP_Get_Manufacturername")]
        public unowned string? get_manufacturer_name ();

        [CCode (cname = "LIBMTP_Get_Serialnumber")]
        public unowned string? get_serial_number ();

        [CCode (cname = "LIBMTP_Get_Deviceversion")]
        public unowned string? get_device_version ();

        [CCode (cname = "LIBMTP_Get_Storage")]
        public int get_storage (int sortby);

        [CCode (cname = "LIBMTP_Dump_Device_Info")]
        public void dump_device_info ();

        [CCode (cname = "LIBMTP_Dump_Errorstack")]
        public void dump_errorstack ();

        [CCode (cname = "LIBMTP_Clear_Errorstack")]
        public void clear_errorstack ();

        [CCode (cname = "LIBMTP_Get_Batterylevel")]
        public int get_battery_level (out uint8 maxlevel, out uint8 curlevel);

        /* File listing: requires an uncached device session. */
        [CCode (cname = "LIBMTP_Get_Files_And_Folders")]
        public unowned File? get_files_and_folders (uint32 storage_id, uint32 parent_id);

        /*
         * Download a file by its MTP object id to a local path.
         * Returns 0 on success.
         */
        [CCode (cname = "LIBMTP_Get_File_To_File")]
        public int get_file_to_file (uint32 id, string path, ProgressFunc? callback, void* data);

        /*
         * Same as get_file_to_file but for tracks (thin wrapper in libmtp).
         * Prefer this when the object is known to be audio.
         */
        [CCode (cname = "LIBMTP_Get_Track_To_File")]
        public int get_track_to_file (uint32 id, string path, ProgressFunc? callback, void* data);

        /*
         * Stream a file by object id into an open file descriptor.
         * Blocks until the whole object is written or an error occurs.
         * Returns 0 on success.
         */
        [CCode (cname = "LIBMTP_Get_File_To_File_Descriptor")]
        public int get_file_to_file_descriptor (uint32 id, int fd, ProgressFunc? callback, void* data);

        /*
         * Upload a local file to the device. filedata carries the destination
         * filename / parent / storage; its item_id is filled in on success.
         * Returns 0 on success.
         */
        [CCode (cname = "LIBMTP_Send_File_From_File")]
        public int send_file_from_file (string path, File filedata, ProgressFunc? callback, void* data);

        /*
         * Stream upload from a handler callback instead of a local file.
         * Useful for unknown-length streams.
         */
        [CCode (cname = "LIBMTP_Send_File_From_Handler")]
        public int send_file_from_handler (DataGetFunc get_func, void* priv, File filedata, ProgressFunc? callback, void* data);

        /*
         * Read a byte range from an object. data is allocated by libmtp;
         * caller must free it with GLib.free(). Returns 0 on success.
         * maxlen is capped at 0xFFFFFFFF by the protocol.
         */
        [CCode (cname = "LIBMTP_GetPartialObject")]
        public int get_partial_object (uint32 id, uint64 offset, uint32 maxlen, out uint8* data, out uint size);

        /*
         * Write a byte range into an existing object. Requires BeginEditObject
         * first on devices that support in-place edits.
         */
        [CCode (cname = "LIBMTP_SendPartialObject")]
        public int send_partial_object (uint32 id, uint64 offset, uint8* data, uint size);

        [CCode (cname = "LIBMTP_BeginEditObject")]
        public int begin_edit_object (uint32 id);

        [CCode (cname = "LIBMTP_EndEditObject")]
        public int end_edit_object (uint32 id);

        [CCode (cname = "LIBMTP_TruncateObject")]
        public int truncate_object (uint32 id, uint64 newsize);

        /*
         * Retrieve rich metadata for a single track (title, artist, album, etc.).
         * WARNING: O(n) and involves USB traffic — do not call in a tight loop
         * over every file if the library is large. Prefer Get_Tracklisting when
         * scanning everything.
         * Caller must free the returned Track with destroy_track_t().
         */
        [CCode (cname = "LIBMTP_Get_Trackmetadata")]
        public Track? get_trackmetadata (uint32 trackid);

        /*
         * Read an arbitrary device/object property as a u32.
         * object_id 0 = the device itself. Used for MTP Perceived Device Type (0xD407).
         */
        [CCode (cname = "LIBMTP_Get_u32_From_Object")]
        public uint32 get_u32_from_object (uint32 object_id, uint32 attribute_id, uint32 value_default);

        /*
         * Read a device property value (GetDevicePropValue, 0x1015).
         * out_val is a LIBMTP_device_prop_value_t*; caller must free with
         * LIBMTP_FreeMemory. Returns 0 on success.
         */
        [CCode (cname = "LIBMTP_Get_DevicePropValue")]
        public int get_device_prop_value (uint16 prop, out void* out_val);

        /*
         * Check whether the device supports a given capability
         * (partial object, send partial, edit, move, copy).
         * Returns 1 if supported, 0 otherwise.
         */
        [CCode (cname = "LIBMTP_Check_Capability")]
        public int check_capability (Devicecap cap);

        /*
         * Bind as pointer (not Vala array) so the C call stays
         * LIBMTP_Detect_Raw_Devices(LIBMTP_raw_device_t **, int *)
         * and does not gain an extra length argument.
         */
        [CCode (cname = "LIBMTP_Detect_Raw_Devices")]
        public static int detect_raw_devices (out RawDevice* devices, out int numdevs);

        [CCode (cname = "LIBMTP_Open_Raw_Device_Uncached")]
        public static unowned Device? open_raw_device_uncached (RawDevice raw);
    }

    [CCode (cname = "LIBMTP_raw_device_t", has_type_id = false, copy_function = "")]
    public struct RawDevice {
        public uint32 bus_location;
        public uint8 devnum;
        public uint16 vendor;
        public uint16 product_id;
        public uint32 device_flags;
    }

    /* MTP file / folder entry. Strings are libmtp-owned; copy before use. */
    [CCode (cname = "LIBMTP_file_t", free_function = "LIBMTP_destroy_file_t", has_type_id = false, copy_function = "")]
    [Compact]
    public class File {
        public uint32 item_id;
        public uint32 parent_id;
        public uint32 storage_id;
        public unowned string? filename;
        public uint64 filesize;
        public ulong modificationdate;
        public Filetype filetype;
        public unowned File? next;
    }

    [CCode (cname = "LIBMTP_destroy_file_t")]
    public static void destroy_file_t (File file);

    /*
     * Full track metadata (title, artist, album, duration, …).
     * Returned by get_trackmetadata / Get_Tracklisting.
     * Free with destroy_track_t().
     */
    [CCode (cname = "LIBMTP_track_t", free_function = "LIBMTP_destroy_track_t", has_type_id = false, copy_function = "")]
    [Compact]
    public class Track {
        public uint32 item_id;
        public uint32 parent_id;
        public uint32 storage_id;
        public unowned string? title;
        public unowned string? artist;
        public unowned string? composer;
        public unowned string? genre;
        public unowned string? album;
        public unowned string? date;
        public unowned string? filename;
        public uint16 tracknumber;
        public uint32 duration;          /* milliseconds */
        public uint32 samplerate;
        public uint16 nochannels;
        public uint32 wavecodec;
        public uint32 bitrate;
        public uint16 bitratetype;
        public uint16 rating;
        public uint32 usecount;
        public uint64 filesize;
        public ulong modificationdate;
        public Filetype filetype;
        public unowned Track? next;
    }

    [CCode (cname = "LIBMTP_destroy_track_t")]
    public static void destroy_track_t (Track track);

    [CCode (cname = "LIBMTP_FILES_AND_FOLDERS_ROOT")]
    public const uint32 FILES_AND_FOLDERS_ROOT;

    [CCode (cname = "LIBMTP_filetype_t", cprefix = "LIBMTP_FILETYPE_", has_type_id = false)]
    public enum Filetype {
        FOLDER,
        WAV,
        MP3,
        MPEG,
        WMA,
        OGG,
        AUDIBLE,
        MP4,
        UNDEF_AUDIO,
        WMV,
        AVI,
        ASF,
        QT,
        UNDEF_VIDEO,
        JPEG,
        JFIF,
        TIFF,
        BMP,
        GIF,
        PNG,
        JP2,
        JPX,
        MHT,
        WPL_PLAYLIST,
        M3U_PLAYLIST,
        PLS_PLAYLIST,
        XML_DOCUMENT,
        FLAC,
        DNG,
        UNKNOWN
    }

    /* Device capability flags for Check_Capability. */
    [CCode (cname = "LIBMTP_devicecap_t", cprefix = "LIBMTP_DEVICECAP_", has_type_id = false)]
    public enum Devicecap {
        GetPartialObject,
        SendPartialObject,
        EditObjects,
        MoveObject,
        CopyObject
    }

    /*
     * libmtp's official audio test macro (LIBMTP_FILETYPE_IS_AUDIO).
     * Covers WAV/MP3/MP2/WMA/OGG/FLAC/AAC/M4A/AUDIBLE/UNDEF_AUDIO.
     */
    [CCode (cname = "LIBMTP_FILETYPE_IS_AUDIO")]
    public static bool filetype_is_audio (Filetype filetype);

    /* Video test: WMV/AVI/MPEG/UNDEF_VIDEO. */
    [CCode (cname = "LIBMTP_FILETYPE_IS_VIDEO")]
    public static bool filetype_is_video (Filetype filetype);

    /* Image test: JPEG/JFIF/TIFF/BMP/GIF/PICT/PNG/JP2/JPX/WindowsImageFormat. */
    [CCode (cname = "LIBMTP_FILETYPE_IS_IMAGE")]
    public static bool filetype_is_image (Filetype filetype);

    [CCode (cname = "LIBMTP_Init")]
    public static void init ();

    [CCode (cname = "LIBMTP_Set_Debug")]
    public static void set_debug (int level);

    /* Cached session — do NOT use when you need Get_Files_And_Folders */
    [CCode (cname = "LIBMTP_Get_First_Device")]
    public static unowned Device? get_first_device ();

    [CCode (cname = "LIBMTP_Release_Device")]
    public static void release_device (unowned Device device);
}
