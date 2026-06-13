!ifndef APP_VERSION
  !error "APP_VERSION is required."
!endif
!ifndef RELEASE_DIR
  !error "RELEASE_DIR is required."
!endif
!ifndef OUTPUT_FILE
  !error "OUTPUT_FILE is required."
!endif
!ifndef ICON_FILE
  !error "ICON_FILE is required."
!endif

Unicode True
Name "Terafoods POS"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Terafoods POS"
RequestExecutionLevel user
Icon "${ICON_FILE}"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Terafoods POS"
  SetOutPath "$INSTDIR"
  File /r "${RELEASE_DIR}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\Terafoods POS.lnk" "$INSTDIR\local_pos.exe"
  CreateDirectory "$SMPROGRAMS\Terafoods POS"
  CreateShortcut "$SMPROGRAMS\Terafoods POS\Terafoods POS.lnk" "$INSTDIR\local_pos.exe"
  CreateShortcut "$SMPROGRAMS\Terafoods POS\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Terafoods POS.lnk"
  Delete "$SMPROGRAMS\Terafoods POS\Terafoods POS.lnk"
  Delete "$SMPROGRAMS\Terafoods POS\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Terafoods POS"
  RMDir /r "$INSTDIR"
SectionEnd
