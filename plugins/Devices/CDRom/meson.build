cdrom_files = files(
  'CDRom.vala',
  'CDRomHelper.vala',
  'CDRomDevice.vala',
  'CDRomDeviceManager.vala',
  'CDRomLibrary.vala',
  'CDRomStreamer.vala',
)

shared_module(
  'cdrom-device',
  cdrom_files,
  dependencies: [ app_dep ],
  install: true,
  install_dir: plugindir
)

install_data('cdrom-device.plugin', install_dir: plugindir)
