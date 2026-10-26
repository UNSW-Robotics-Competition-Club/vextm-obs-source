;--------------------------------
;Include to detect if running on a 64-bit machine
  !include "x64.nsh"

;--------------------------------
;Include Modern UI

  !include "MUI.nsh"

  !addplugindir "Installer"

;--------------------------------
;Build-time settings, override with makensis /D

  !ifndef VERSION
    !define VERSION "1.3-obs33"
  !endif
  !ifndef DLL_PATH
    !define DLL_PATH "vextm-source.dll"
  !endif

;--------------------------------
;General

  ;Name and file
  Name "VEX Tournament Manager OBS Plugin"
  BrandingText "VEX Tournament Manager OBS Plugin ${VERSION}"
  OutFile "VEXTMOBSPluginInstaller.exe"
  Unicode true

  ; Set requested execution level as Administrator. This is needed to write
  ; to ProgramData and to remove old copies from Program Files.
  RequestExecutionLevel admin

  ; OBS 32+ loads third-party plugins from per-plugin folders under
  ; %ProgramData%\obs-studio\plugins rather than Program Files
  !define PLUGIN_DIR "$COMMONPROGRAMDATA\obs-studio\plugins\vextm-source"
  !define LEGACY_DLL "$PROGRAMFILES64\obs-studio\obs-plugins\64bit\vextm-source.dll"
  !define LEGACY_DATA "$PROGRAMFILES64\obs-studio\data\obs-plugins\vextm-source"
  !define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\vextm-source"

  VIProductVersion "1.3.0.33"
  VIAddVersionKey "ProductName" "VEX Tournament Manager OBS Plugin"
  VIAddVersionKey "FileDescription" "VEX Tournament Manager OBS Plugin Installer"
  VIAddVersionKey "FileVersion" "${VERSION}"
  VIAddVersionKey "ProductVersion" "${VERSION}"
  VIAddVersionKey "LegalCopyright" "GPL-2.0"

;--------------------------------
;Installation Types

  InstType "Full"

;--------------------------------
;Don't show installation details
  ShowInstDetails nevershow
  ShowUninstDetails nevershow

;--------------------------------
;Interface Settings

  !define MUI_ABORTWARNING
  !define MUI_COMPONENTSPAGE_SMALLDESC

;--------------------------------
;Theme Settings

  !define MUI_ICON   "Installer\installer-nopng.ico"
  !define MUI_UNICON "Installer\uninstaller-nopng.ico"

  ; MUI Settings / Header
  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_RIGHT
  !define MUI_HEADERIMAGE_BITMAP   "Installer\header-r.bmp"
  !define MUI_HEADERIMAGE_UNBITMAP "Installer\header-r-un.bmp"

  ; MUI Settings / Wizard
  !define MUI_WELCOMEFINISHPAGE_BITMAP   "Installer\wizard.bmp"
  !define MUI_UNWELCOMEFINISHPAGE_BITMAP "Installer\wizard-un.bmp"

;--------------------------------
;Pages

  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_INSTFILES
  !insertmacro MUI_PAGE_FINISH

  !insertmacro MUI_UNPAGE_CONFIRM
  !insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
;Languages
  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Helpers

; Leaves 0 on the stack if OBS is running, 1 otherwise
!macro CheckObsRunning
  nsExec::Exec 'cmd /c tasklist /FI "IMAGENAME eq obs64.exe" /NH | find /I "obs64.exe"'
!macroend

Function .onInit
    ; Check for OBS Studio install
    IfFileExists "$PROGRAMFILES64\obs-studio\bin\64bit\obs64.exe" checkRunning 0
        MessageBox MB_ICONSTOP|MB_OK "You must install OBS Studio before installing this plugin." /SD IDOK
        Abort

    checkRunning:
    !insertmacro CheckObsRunning
    Pop $0
    StrCmp $0 "0" 0 continueInstall
        MessageBox MB_ICONEXCLAMATION|MB_RETRYCANCEL "OBS Studio is running. Close it, then click Retry." /SD IDCANCEL IDRETRY checkRunning
        Abort

    continueInstall:
FunctionEnd

Function un.onInit
    checkRunning:
    !insertmacro CheckObsRunning
    Pop $0
    StrCmp $0 "0" 0 continueUninstall
        MessageBox MB_ICONEXCLAMATION|MB_RETRYCANCEL "OBS Studio is running. Close it, then click Retry." /SD IDCANCEL IDRETRY checkRunning
        Abort

    continueUninstall:
FunctionEnd

;--------------------------------
;Installer Sections

Section "-Base"
  SetDetailsPrint textonly
  DetailPrint "Installing base files..."
  SetDetailsPrint none

  ; Remove copies installed by earlier versions into the legacy plugin
  ; folder, which OBS 33 can't load and would otherwise shadow this one
  Delete "${LEGACY_DLL}"
  RMDir /r "${LEGACY_DATA}"

  SetOutPath "${PLUGIN_DIR}\bin\64bit"
  File "/oname=vextm-source.dll" "${DLL_PATH}"
  SetOutPath "${PLUGIN_DIR}\data"
  File /r data\*.*

  WriteUninstaller "${PLUGIN_DIR}\uninstall.exe"

  ; Add/Remove Programs entry
  SetRegView 64
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "VEX Tournament Manager OBS Plugin"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "UNSW Robotics Competition Club"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "${PLUGIN_DIR}\uninstall.exe"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "${PLUGIN_DIR}"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"${PLUGIN_DIR}\uninstall.exe"'
  WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "https://github.com/UNSW-Robotics-Competition-Club/vextm-obs-source"
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
SectionEnd

;--------------------------------
;Uninstaller Section

Section "Uninstall"
  RMDir /r "${PLUGIN_DIR}"
  SetRegView 64
  DeleteRegKey HKLM "${UNINST_KEY}"
SectionEnd
