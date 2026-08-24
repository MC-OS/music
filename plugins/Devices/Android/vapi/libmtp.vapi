/* Minimal libmtp bindings — names + storage only (chunk 1). */
[CCode (cheader_filename = "libmtp.h", cprefix = "LIBMTP_", lower_case_cprefix = "LIBMTP_")]
namespace Mtp {

    [CCode (cname = "LIBMTP_devicestorage_t", free_function = "", unref_function = "", has_type_id = false)]
    [Compact]
    public class Storage {
        public uint32 id;
        public uint64 MaxCapacity;
        public uint64 FreeSpaceInBytes;
        public unowned string? StorageDescription;
        public unowned Storage? next;
    }

    [CCode (cname = "LIBMTP_mtpdevice_t", free_function = "LIBMTP_Release_Device", unref_function = "", has_type_id = false)]
    [Compact]
    public class Device {
        public unowned Storage? storage;

        [CCode (cname = "LIBMTP_Get_Friendlyname")]
        public string? get_friendly_name ();

        [CCode (cname = "LIBMTP_Get_Modelname")]
        public string? get_model_name ();

        [CCode (cname = "LIBMTP_Get_Manufacturername")]
        public string? get_manufacturer_name ();

        [CCode (cname = "LIBMTP_Get_Serialnumber")]
        public string? get_serial_number ();

        [CCode (cname = "LIBMTP_Get_Storage")]
        public int get_storage (int sortby);
    }

    [CCode (cname = "LIBMTP_Init")]
    public static void init ();

    [CCode (cname = "LIBMTP_Get_First_Device")]
    public static Device? get_first_device ();

    [CCode (cname = "LIBMTP_Release_Device")]
    public static void release_device (Device device);
}
