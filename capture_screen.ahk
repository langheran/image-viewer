; For example get the cmd's hwnd
Run, %ComSpec%,,, pid
WinWait, ahk_pid %pid%
hwnd := WinExist()

; hwnd -> pBitmap -> hBitmap
pToken  := Gdip_Startup()
pBitmap := Gdip_BitmapFromHWND(hwnd)
hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)

; Close cmd
WinClose

Gui, Add, Text, 0xE w500 h300 hwndhPic          ; SS_Bitmap    = 0xE
SendMessage, 0x172, 0, hBitmap, , ahk_id %hPic% ; STM_SETIMAGE = 0x172
Gui, Show
Return

GuiClose:
	Gdip_ShutDown(pToken)
ExitApp