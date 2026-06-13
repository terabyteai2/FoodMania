# Desktop release packages

The desktop POS is part of this Flutter application. Native Linux, macOS, and
Windows launches route into `lib/src/features/desktop_pos/desktop_pos_shell.dart`.
Android, iOS, and web keep the existing mobile application shell.

## Linux debug launch

The Snap Flutter toolchain can mix its bundled GLib and linker with newer host
libraries. Run the host-toolchain debug launcher instead:

```bash
./tool/run_linux_debug.sh
```

## Linux `.deb`

Run on Linux:

```bash
./tool/build_linux_deb.sh
```

The package is written to `dist/terafoods-pos_<version>_<architecture>.deb`.

## Windows `.exe`

Run in PowerShell on a Windows development machine with Flutter and Visual
Studio Desktop development with C++ installed:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tool\build_windows_release.ps1
```

The script writes the runnable `local_pos.exe` and its required adjacent files
to `dist/Terafoods-POS-Windows-<version>/`, plus a portable `.zip`. A lone
Flutter `.exe` is not distributable without the DLL and `data` files beside it.

When NSIS is installed, the script also creates
`dist/Terafoods-POS-Setup-<version>.exe`.
