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
    }

    [CCode (cname = "LIBMTP_Init")]
    public static void init ();

    [CCode (cname = "LIBMTP_Set_Debug")]
    public static void set_debug (int level);

    /* Returned pointer is managed only via release_device() */
    [CCode (cname = "LIBMTP_Get_First_Device")]
    public static unowned Device? get_first_device ();

    [CCode (cname = "LIBMTP_Release_Device")]
    public static void release_device ([CCode (destroy_notify_pos = -1)] Device device);
}
