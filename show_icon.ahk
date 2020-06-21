#SingleInstance, force
ptr := A_PtrSize =8 ? "ptr" : "uint"   ;for AHK Basic
WS_BORDER := 0x00800000
; Gui, 1: +AlwaysOnTop +ToolWindow -SysMenu -Caption
Gui, 1:  Margin, 20, 20

FileName := "C:\Program Files\MATLAB\R2018b\bin\win64\MATLAB.exe"
FileName := "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
Loop 3{
    i:=A_Index
    hIcon := DllCall("Shell32\ExtractAssociatedIcon" (A_IsUnicode ? "W" : "A"), ptr, DllCall("GetModuleHandle", ptr, 0, ptr), str, FileName, "ushort*", lpiIcon, ptr)   ;only supports 32x32
    sep:=10
    if(i==1)
        sep:=0
    Gui, 1:  Add, Text, w32 h32 x+%sep% y20 vText%i% hwndmyIcon%i% 0x3 ; 0x3 = SS_ICON
    myIcon:=myIcon%i%
    SendMessage, STM_SETICON := 0x0170, hIcon, 0,, Ahk_ID %myIcon%
    if(i==2)
        WinSet, Style, +%WS_BORDER%, ahk_id %myIcon%
}
Gui, 1:  Show
Return

GuiClose:
GuiEscape:
ExitApp