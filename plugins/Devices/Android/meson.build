Android_files = files(
  'Android.vala',
  'AndroidDeviceManager.vala',
  'AndroidDevice.vala',
  'AndroidLibrary.vala',
  'MtpConsoleProbe.vala',
)

shared_module(
  'android-device',
  Android_files,
  vala_args: ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
  dependencies: [
    app_dep,
    dependency('libmtp')
  ],
  install: true,
  install_dir: plugindir
)

install_data('android-device.plugin', install_dir: plugindir)
