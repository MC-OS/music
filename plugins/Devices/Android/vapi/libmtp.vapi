/* libmtp bindings for native MTP console probe (info dump / rename later). */
[CCode (cheader_filename = "libmtp.h", cprefix = "LIBMTP_", lower_case_cprefix = "LIBMTP_")]
namespace Mtp {

    [CCode (cname = "LIBMTP_devicestorage_t", free_function = "", unref_function = "", has_type_id = false)]
    [Compact]
    public class Storage {
        public uint32 id;
        public uint64 MaxCapacity;
        public uint64 FreeSpaceInBytes;
        public unowned string? StorageDescription;
        public unowned string? VolumeIdentifier;
        public unowned Storage? next;
    }

    [CCode (cname = "LIBMTP_mtpdevice_t", free_function = "LIBMTP_Release_Device", unref_function = "", has_type_id = false)]
    [Compact]
    public class Device {
        public unowned Storage? storage;

        [CCode (cname = "LIBMTP_Get_Friendlyname")]
        public string? get_friendly_name ();

        [CCode (cname = "LIBMTP_Set_Friendlyname")]
        public int set_friendly_name (string name);

        [CCode (cname = "LIBMTP_Get_Modelname")]
        public string? get_model_name ();

        [CCode (cname = "LIBMTP_Get_Manufacturername")]
        public string? get_manufacturer_name ();

        [CCode (cname = "LIBMTP_Get_Serialnumber")]
        public string? get_serial_number ();

        [CCode (cname = "LIBMTP_Get_Deviceversion")]
        public string? get_device_version ();

        [CCode (cname = "LIBMTP_Get_Storage")]
        public int get_storage (int sortby);

        [CCode (cname = "LIBMTP_Dump_Device_Info")]
        public void dump_device_info ();

        [CCode (cname = "LIBMTP_Dump_Errorstack")]
        public void dump_errorstack ();

        [CCode (cname = "LIBMTP_Clear_Errorstack")]
        public void clear_errorstack ();

        /* Returns 0 on success */
        [CCode (cname = "LIBMTP_Get_Batterylevel")]
        public int get_battery_level (out uint8 maxlevel, out uint8 curlevel);
    }

    [CCode (cname = "LIBMTP_Init")]
    public static void init ();

    [CCode (cname = "LIBMTP_Set_Debug")]
    public static void set_debug (int level);

    [CCode (cname = "LIBMTP_Get_First_Device")]
    public static Device? get_first_device ();

    [CCode (cname = "LIBMTP_Release_Device")]
    public static void release_device (Device device);
}
