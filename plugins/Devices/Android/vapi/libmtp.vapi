/* libmtp bindings — compact handles, no Vala ownership transfer */
[CCode (cheader_filename = "libmtp.h", cprefix = "LIBMTP_", lower_case_cprefix = "LIBMTP_")]
namespace Mtp {

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

        [CCode (cname = "LIBMTP_Detect_Raw_Devices")]
        public static int detect_raw_devices (out unowned RawDevice[]? devices, out int numdevs);

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
