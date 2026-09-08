cdrom_files = files(
  'CD.vala',
  'CDDevice.vala',
  'CDDeviceManager.vala',
  'CDLibrary.vala',
  'CDStreamer.vala',
  'CDImport.vala'
)

shared_module(
  'cdrom-device',
  cdrom_files,
  dependencies: [ app_dep ],
  install: true,
  install_dir: plugindir
)

install_data('cdrom-device.plugin', install_dir: plugindir)
