#SingleInstance, Off
#Include Gdip_All.ahk
#Include GDIplusWrapper.ahk
#Include WinClipAPI.ahk
#Include WinClip.ahk
#include FileMD5.ahk
#NoEnv
#Persistent
#MaxHotkeysPerInterval, 99999999
OutputDebug DBGVIEWCLEAR

WinGet, currentDocumentId, ID, A

GoSub, AssociateFileExtension
SysGet, workArea, MonitorWorkArea
this_pid:=DllCall("GetCurrentProcessId")

GetModuleCommandLineHash:={}
GetModuleCommandLineFileHash:={}

GoSub, ResumeOnMessage

IniRead,clipboardDirectory,%A_ScriptDir%\image.ini,settings,clipboardDirectory,%A_ScriptDir%\clipboard
IniWrite, %clipboardDirectory%,%A_ScriptDir%\image.ini,settings,clipboardDirectory
baseFile:=A_ScriptDir . "\image.png"
clipboardBaseFile:=clipboardDirectory . "\001.png"
dock_image:=0

args:=""
Loop, %0%  ; For each parameter:
{
    param := %A_Index%
	num = %A_Index%
	args := args . param
}
if(args="")
	args:=A_WorkingDir

if(FileExist(args) && A_WorkingDir<>args)
{
    SplitPath, args, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
    FileGetAttrib, Attributes, %args%
    if(OutExtension="imgx")
    {
        sessionFile:=args
        GoSub, OpenSessionFile
        ExitApp
    }
    else if(InStr(Attributes, "D"))
    {
        imagesFolder:=args
        GoSub, OpenImagesFolder
        ExitApp
    }
    else
    {
        IniRead, reload, %A_ScriptDir%\image.ini, %args%, reload, 0
        if(WinAlreadyOpen(args) && !reload)
        {
            WinActivate, % "ahk_id " GetGuiIDFromPID(GetModuleCommandLineFileHash[args])
            ExitApp
        }
        SetImageFile(args)
        HasArgs:=1
    }
}
else
{
    if(args="s")
    {
        IniRead,mostRecentSessionFile,%A_ScriptDir%\image.ini,recent_sessions,1
        if(FileExist(mostRecentSessionFile))
        {
            sessionFile:=mostRecentSessionFile
            GoSub, OpenSessionFile
        }
    }
    else
        HasArgs:=0
}

pToken := Gdip_Startup()
pBitmap := Gdip_CreateBitmapFromClipboard()
Gdip_DisposeImage(pBitmap)
Gdip_Shutdown(pToken)
DllCall("CloseClipboard")
if(!HasArgs)
{
    if(pBitmap>=0)
    {
        imageFile:=baseFile
        pToken := Gdip_Startup()
        Gdip_SaveBitmapToFile(pBitmap := Gdip_CreateBitmapFromClipboard(), imageFile , Quality=100)
        Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
        DllCall("CloseClipboard")
        GoSub, SaveImageIntoClipboardFolder
        imageFile:=clipboardBaseFile
        SetImageFile(imageFile)
        dock_image:=1
    }
    else
    {
        IniRead,mostRecentImageFile,%A_ScriptDir%\image.ini,recents,1
        if(!FileExist(mostRecentImageFile))
            SetImageFile(baseFile)
        else
        {
            ;SetImageFile(mostRecentImageFile)
            command="%A_ScriptFullPath%" "%mostRecentImageFile%"
            Run, %command%
            ExitApp
        }
    }
}

OnExit, ExitApplication
GoSub, BuildTrayMenu

FileGetSize, nBytes, %imageFile%
FileRead, Bin, *c %imageFile%
Base64ImageData := Base64Enc( Bin, nBytes, 100, 2 )
VectorImage := ComObjCreate( "WIA.Vector" )
VectorImage.BinaryData := Base64ToComByteArray( Base64ImageData ) 
Picture := VectorImage.Picture
VectorImage := "" 
hBM := Picture.Handle

Gui, Main: Margin, 0, 0
Gui, Main: Color, feffff
BITMAP := getHBMinfo( hBM ) 
GoSub, LoadCurrentSettings
if(_X=-1 || _X="ERROR")
{
    dock_image:=1
}
Gui, Main: Add, Picture, y0 x0 vImage BackgroundTrans, HBITMAP:%hBM%
Gui, Main: -Caption +LastFound +AlwaysOnTop +OwnDialogs +Hwndthis_id +Resize ; +ToolWindow
GoSub, DisplayImage
WinSet, TransColor, feffff
GuiID:=WinExist()
if(dock_image)
    GoSub, DockImage
IniWrite, 1, %A_ScriptDir%\image.ini, %imageFile%, opened
IniWrite, 0, %A_ScriptDir%\image.ini, %imageFile%, reload
return

OpenImagesFolder:
extensions:="jpg,png,tif,bmp,gif"
Loop, Files, %imagesFolder%\*
{
    if A_LoopFileExt in %extensions%
	{
        newImageFile:=A_LoopFileLongPath
        Run, "%A_ScriptFullPath%" "%newImageFile%"
        Loop{
            IniRead, opened, %A_ScriptDir%\image.ini, %newImageFile%, opened, 0
            if(opened)
                break
            else
                Sleep, 10
        }
        Sleep, 500
        if(currentDocumentId)
        {
            WinActivate, ahk_id %currentDocumentId%
            WinWaitActive, ahk_id %currentDocumentId%,, 1
        }
    }
}
GoSub, SaveFolderAsSession
return

ResumeOnMessage:
OnMessage(0x4a, "Receive_WM_COPYDATA")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x204, "WM_RBUTTONDOWN")
OnMessage(0x05, "WM_SIZE")
OnMessage(0x06, "TestActive") ; WM_ACTIVATE
OnMessage(0x07, "TestActive") ; WM_SETFOCUS
OnMessage(0x08, "TestActive") ; WM_KILLFOCUS
return

PauseOnMessage:
OnMessage(0x4a, "WM_SINK")
OnMessage(0x201, "WM_SINK")
OnMessage(0x204, "WM_SINK")
OnMessage(0x05, "WM_SINK")
OnMessage(0x06, "WM_SINK") ; WM_ACTIVATE
OnMessage(0x07, "WM_SINK") ; WM_SETFOCUS
OnMessage(0x08, "WM_SINK") ; WM_KILLFOCUS
return

OpenSessionFile:
RebuildRecentSessions(sessionFile)
IniRead,filesSection,%sessionFile%,files
Loop,Parse,filesSection,`n,`r
{
    newImageFile:=LTrim(RTrim(StrSplit(A_LoopField, "=")[2]))
    Run, "%A_ScriptFullPath%" "%newImageFile%"
    Loop{
        IniRead, opened, %A_ScriptDir%\image.ini, %newImageFile%, opened, 0
        if(opened)
            break
        else
            Sleep, 10
    }
    Sleep, 1000
    if(currentDocumentId)
    {
        WinActivate, ahk_id %currentDocumentId%
        WinWaitActive, ahk_id %currentDocumentId%,, 1
    }
}
IniWrite, session, %A_ScriptDir%\image.ini, settings, saveDestiny
return

AssociateFileExtension:
; Create a reg key name (Demo) and a real name (Demo Player File). <- This is
; the name of the file type when you right-click properties on the file.
RegWrite, REG_SZ, HKCR, IMGX, , Image Session File

; Tell the system to open the file using whatever program you want (%A_WorkingDir%\Demo Player.exe).
; (%1 is the variable which stores the file name to pass to the script)
RegWrite, REG_SZ, HKCR, IMGX\Shell\Open\Command, , %A_ScriptDir%\image.exe "`%1"

; Assign this file type an icon of your choice (can be the same as the Demo Player.exe but for this
; example i want the files to lok different to the program so I chose a custome file.
RegWrite, REG_SZ, HKCR, IMGX\DefaultIcon, , %A_ScriptDir%\image.ico

; Finally, Associate all .demo file extensions with the reg key Demo.
RegWrite, REG_SZ, HKCR, .imgx, , IMGX
return

BuildTrayMenu:
Menu, Tray, NoStandard
Menu, Tray, Icon , %A_ScriptDir%/image.ico, , 1 
command:=LTrim(RTrim(imageFile))
if(command=baseFile && !HasArgs)
    command:=clipboardBaseFile
UpdateRecentSessions()
i:=1
for k, v in recentSessions
{
    if(i>=10)
        break
	if(command<>v || True)
	{
		shorcut_number:=i
		if(i<10)
			shorcut_number=&%i%
		Menu, Tray, add, %shorcut_number% %v%, RunRecentSession
		i:=i+1
	}
	else
	{
		currentRecentIndex:=k
	}
}

Menu, Tray, Add
RebuildRecentCommands(command)
i:=1
for k, v in recentCommands
{
    if(i>=10)
        break
	if(command<>v || True)
	{
		shorcut_number:=i
		if(i<10)
			shorcut_number=&%i%
		Menu, Tray, add, %shorcut_number% %v%, RunRecentCommand
		i:=i+1
	}
	else
	{
		currentRecentIndex:=k
	}
}

Menu, Tray, Add
i:=1
Loop, Files, %clipboardDirectory%\*.*
{
    if(i>=10)
        break
    if A_LoopFileExt in png
    {
        shorcut_number:=i
        if(i<10)
            shorcut_number=&%i%
        Menu, Tray, add, %shorcut_number% %clipboardDirectory%\%A_LoopFileName%, RunRecentCommand
        i:=i+1
    }
}

Menu, Tray, Add
Menu, Tray, Add, &Save As..., SaveAs
Menu, Tray, Add, &Save Session As..., SaveSession
Menu, Tray, Add, Copy as &Image, CopyToClipboard
Menu, Tray, Add, Copy as &HTML, CopyAsHTML
Menu, Tray, Add, Copy as &Markdown, CopyAsMarkdown
Menu, Tray, Add, Copy as &Latex, CopyAsLatex
Menu, Tray, Add, Open &Folder, OpenFolder
Menu, Tray, Add
Menu, Tray, Add, Close, ExitApplication
return

RebuildRecentCommands(command)
{
    UpdateRecentCommands(command)
    SaveRecentCommands()
}

RebuildRecentSessions(command)
{   
    UpdateRecentSessions(command)
    SaveRecentSessions()
}

UpdateRecentSessions(command=0)
{
    global recentSessions
    global recentSessionsHash
    recentSessions:=[]
    recentSessionsHash:={}

    IniRead,recentSessionsSection,%A_ScriptDir%\image.ini,recent_sessions
    Loop,Parse,recentSessionsSection,`n,`r
    {
        recentSession:=LTrim(RTrim(StrSplit(A_LoopField, "=")[2]))
        if(!recentSessionsHash.HasKey(recentSession) && (!command || recentSession<>command))
        {
            if(FileExist(recentSession))
            {
                recentSessions.Push(recentSession), 	recentSessionsHash[recentSession]:=1
            }
        }
    }
    if(command)
        InsertRecentSession(command)
}

UpdateRecentCommands(command=0)
{
    global recentCommands
    global recentCommandsHash
    recentCommands:=[]
    recentCommandsHash:={}
    global clipboardDirectory

    IniRead,recentsSection,%A_ScriptDir%\image.ini,recents
    Loop,Parse,recentsSection,`n,`r
    {
        recentCommand:=LTrim(RTrim(StrSplit(A_LoopField, "=")[2]))
        if(!recentCommandsHash.HasKey(recentCommand) && (!command || recentCommand<>command))
        {
            if(FileExist(recentCommand) && !InStr(recentCommand,clipboardDirectory))
            {
                recentCommands.Push(recentCommand), 	recentCommandsHash[recentCommand]:=1
            }
        }
    }
    if(command)
        InsertRecentCommand(command)
}

SetImageFile(newImageFile)
{
    global imageFile
    global stackWindows
    global GuiTitle

    GoSub, SaveCurrentPosition
    if(stackWindows)
        IniDelete, %A_ScriptDir%\image.ini,stackY,%imageFile%
    imageFile:=newImageFile
    FileCopy, %imageFile% ,% A_ScriptDir . "\image.png", 1
    GoSub, LoadCurrentSettings
    RebuildRecentCommands(imageFile)
    SplitPath, imageFile, GuiTitle
    IniWrite, %A_Now%, %A_ScriptDir%\image.ini, %imageFile%, LastOpened
    IniWrite, file, %A_ScriptDir%\image.ini, settings, saveDestiny
}

GetCurrentPosition:
    WinGetPos , _newX, _newY,,, % "ahk_id " . this_id
    if(_newX!=-32000)
        _X:=_newX
    if(_newY!=-32000)
        _Y:=_newY
    GuiControlGet, ImagePos, Main:Pos, Image
    _Width:=ImagePosW
    _Height:=ImagePosH
return

SaveCurrentPosition:
    GoSub, GetCurrentPosition
SavePosition:
    if(FileExist(imageFile))
    {
        IniWrite, %_X%, %A_ScriptDir%\image.ini, %imageFile%, X
        IniWrite, %_Y%, %A_ScriptDir%\image.ini, %imageFile%, Y
        IniWrite, %_Width%, %A_ScriptDir%\image.ini, %imageFile%, Width
        IniWrite, %_Height%, %A_ScriptDir%\image.ini, %imageFile%, Height
    }
return

LoadCurrentSettings:
    IniRead, _X, %A_ScriptDir%\image.ini, %imageFile%, X,-1
    IniRead, _Y, %A_ScriptDir%\image.ini, %imageFile%, Y,-1
    IniRead, _Width, %A_ScriptDir%\image.ini, %imageFile%, Width,-1
    IniRead, _Height, %A_ScriptDir%\image.ini, %imageFile%, Height,-1
    if(_Width=-1 || _Width="ERROR" || _Height=-1 || _Height="ERROR")
    {
        hBM := LoadPicture( imageFile )
        IfEqual, hBM, 0, Return
        BITMAP := getHBMinfo( hBM )
        _Width:=BITMAP.Width
        _Height:=BITMAP.Height
    }
return

SaveImageIntoClipboardFolder:
IfNotExist, %clipboardDirectory%
    FileCreateDir, %clipboardDirectory%
newClipboardImagePath:=A_ScriptDir . "\image.png"
clip1:=FileMD5(newClipboardImagePath)
clip2:=FileMD5(clipboardDirectory . "\001.png")
if(clip1<>clip2)
{
    FileList =
    Loop, Files, %clipboardDirectory%\*.*
    {
    if A_LoopFileExt in png
        FileList = %FileList%%A_LoopFileName%`n
    }
    sort, FileList, fSortByFilenumberDesc
    FileRead, IniText, %A_ScriptDir%\image.ini
    NewIniText:=IniText
    Loop, Parse, FileList, `n
    {
        if(Trim(A_LoopField)="")
            continue
        filePath:= clipboardDirectory . "\" . A_LoopField
        if(FileExist(filePath))
        {
            SplitPath, filePath, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
            number:=RegexReplace(OutFileName, "m)^([\d]{3})(.*)$","$1")
            number:=number+1
            newPath:= OutDir . "\" . SubStr("000" . number, -2) . ".png"
            ;msgbox, %filePath%`, %newPath%
            if(number>150)
                FileDelete, %filePath%
            else
            {
                FileMove, %filePath%, %newPath%
                StringReplace, NewIniText, NewIniText, [%filePath%], [%newPath%], All
            }
        }
    }
    FileDelete, %A_ScriptDir%\image.ini
    FileAppend, %NewIniText%, %A_ScriptDir%\image.ini

    newPath:=clipboardDirectory . "\001.png"
    FileCopy, %newClipboardImagePath%, %newPath%
}
return

SortByFilenumberDesc(a1, a2){
    SplitPath, a1, a1_name, a1_dir, a1_ext, a1_name_no_ext, a1_drive
    SplitPath, a2, a2_name, a2_dir, a2_ext, a2_name_no_ext, a2_drive

    
    RegExMatch(a1_name_no_ext, "O)[^\d]*([\d]+)[^\d]*([\d]*)[^\d]*([\d]*).*", a1_o)
    
    a1:=a1_o[1]*100000
    if(a1_o[2])
        a1:=a1+a1_o[2]*1000
    if(a1_o[3])
        a1:=a1+a1_o[3]
    
    RegExMatch(a2_name_no_ext, "O)[^\d]*([\d]+)[^\d]*([\d]*)[^\d]*([\d]*).*", a2_o)
    a2:=a2_o[1]*100000
    if(a2_o[2])
        a2:=a2+a2_o[2]*1000
    if(a2_o[3])
        a2:=a2+a2_o[3]
    
	return a1 > a2 ? -1 : a1 < a2 ? 1 : 0
}

RunRecentCommand:
newImageFile:=Trim(SubStr(A_ThisMenuItem, InStr(A_ThisMenuItem," ")))
controlPressed:=GetKeyState("Control", "P")
if(!controlPressed)
    Run, "%A_ScriptFullPath%" "%newImageFile%"
else
{
    ; SetImageFile(newImageFile)
    ; GoSub, LoadImage
    Run, "%A_ScriptFullPath%" "%newImageFile%"
    ExitApp
}
return

RunRecentSession:
newSessionFile:=Trim(SubStr(A_ThisMenuItem, InStr(A_ThisMenuItem," ")))
controlPressed:=GetKeyState("Control", "P")
if(!controlPressed)
    CloseOthers(0)
Run, "%A_ScriptFullPath%" "%newSessionFile%"
ExitApp
return

InsertRecentCommand(command)
{
    global recentCommandsHash
    global recentCommands
    if(!recentCommandsHash.HasKey(command))
    {
        recentCommands.InsertAt(1, command)
    }
    while(recentCommands.Length()>31)
        recentCommands.Pop()
}

InsertRecentSession(command)
{
    global recentSessionsHash
    global recentSessions
    if(!recentSessionsHash.HasKey(command))
    {
        recentSessions.InsertAt(1, command)
    }
    while(recentSessions.Length()>31)
        recentSessions.Pop()
}

getHBMinfo( hBM ) {
Local SzBITMAP := ( A_PtrSize = 8 ? 32 : 24 ),  BITMAP := VarSetCapacity( BITMAP, SzBITMAP )       
  If DllCall( "GetObject", "Ptr",hBM, "Int",SzBITMAP, "Ptr",&BITMAP )
    Return {  Width:      Numget( BITMAP, 4, "UInt"  ),  Height:     Numget( BITMAP, 8, "UInt"  ) 
           ,  WidthBytes: Numget( BITMAP,12, "UInt"  ),  Planes:     Numget( BITMAP,16, "UShort") 
           ,  BitsPixel:  Numget( BITMAP,18, "UShort"),  bmBits:     Numget( BITMAP,20, "UInt"  ) }
}       
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ScaleRect( SW, SH, TW, TH, Upscale := 0 ) { ; By SKAN | Created: 19-July-2017 | Topic: goo.gl/  

Local  SAF := SW/SH, TAF := TW/TH ; Aspect ratios of Source and Target
  Return  ( !Upscale and SW <= TW and SH <= TH ) ? {W: SW, H: SH}  
      :   ( SAF < TAF ) ? { W: Floor( ( TW / TAF ) * SAF ), H: TH}
      :   ( SAF > TAF ) ? { W: TW, H: Floor( ( TH / SAF ) * TAF )} 
      :   { W: TW, H: TH }
}

MainGuiClose:
    GoSub, SaveAndExitApplication
return

MainGuiDropFiles:
  ;global
  newImageFile:=StrSplit( A_GuiEvent, "`n" ).1
  SetImageFile(newImageFile)
  GoSub, LoadImage
  GoSub, LoadImage
  GoSub, DisplayImage
return

ResetPosition:
GoSub, ResetWidthHeight
GoSub, ResetXYPosition
GoSub, SaveNewPosition
return

ResetWidthHeight:
hBM := LoadPicture( imageFile )
BITMAP := getHBMinfo( hBM )
GuiControlGet, ImagePos, Main:Pos, Image
_Width:=BITMAP.Width
_Height:=BITMAP.Height
_AspectRatio:=_Width/_Height
return

ResetWidthHeightRatio:
hBM := LoadPicture( imageFile )
BITMAP := getHBMinfo( hBM )
GuiControlGet, ImagePos, Main:Pos, Image
_Width:=BITMAP.Width
_Height:=BITMAP.Height
_AspectRatio:=_Width/_Height

SysGet, Monitor, MonitorWorkArea
MonitorWidth:=MonitorRight-450
_Width:=0+(ratio/8)*(MonitorWidth)
_Height:=_Width/_AspectRatio
return

ResetAspectRatio:
if(A_ThisHotkey="a")
{
    _Height:=_Width/_AspectRatio
}
if(A_ThisHotkey="z")
{
    _Width:=_Height*_AspectRatio
}
return

ResetXYPosition:
GoSub, ResetXPosition
GoSub, ResetYPosition
return

ResetXPosition:
WinGetPos ,,, WindowWidth, WindowHeight, ahk_id %this_id%
ResetX0Position:
_X:=workAreaRight-WindowWidth+7
return

ResetYPosition:
WinGetPos ,,, WindowWidth, WindowHeight, ahk_id %this_id%
ResetY0Position:
_Y:=workAreaBottom-WindowHeight+7
stackWindows:=1
controlPressed:=GetKeyState("Control", "P")
if(stackWindows && controlPressed)
{
    IniWrite,%WindowHeight%,%A_ScriptDir%\image.ini,stackY,%imageFile%
    IniRead,stackYSection,%A_ScriptDir%\image.ini,stackY
    stackY:=0
    WinAlreadyOpen(0)
    Loop,Parse,stackYSection,`n,`r
    {
        fileName:=LTrim(RTrim(StrSplit(A_LoopField, "=")[1]))
        if(!GetModuleCommandLineFileHash.HasKey(fileName) && imageFile!=fileName)
        {
            IniDelete,%A_ScriptDir%\image.ini,stackY,%fileName%
            continue
        }
        stackY:=stackY+LTrim(RTrim(StrSplit(A_LoopField, "=")[2]))
        if(LTrim(RTrim(StrSplit(A_LoopField, "=")[1]))==imageFile)
            break
    }
    _Y:=workAreaBottom-stackY+7
}
return

SaveNewPosition:
GoSub, SavePosition
GoSub, LoadCurrentSettings
return

LoadImage:
  hBM := LoadPicture( imageFile )
  IfEqual, hBM, 0, Return

  BITMAP := getHBMinfo( hBM )                                ; Extract Width andh height of image 
;   msgbox, % imageFile . "--" . newWidth . "-" . newHeight

  _AspectRatio:=BITMAP.Width/BITMAP.Height

  if(scaleImage)
  {
    New := ScaleRect( BITMAP.Width, BITMAP.Height, _Width, _Height )  ; Derive best-fit W x H for source image 
    DllCall( "DeleteObject", "Ptr",hBM )                       ; Delete Image handle ...         
    hBM := LoadPicture( imageFile, "GDI+ w" New.W . " h" . New.H )  ; ..and get a new one with correct W x H
    newWidth:="w" . New.W
    newHeight:="h" . New.H
  }
  GuiControl, Main:, -Redraw, Image
  GuiControl, Main:, Image, HBITMAP:%hBM% 
  GuiControl, Main:, +Redraw, Image
Return

DisplayImage:
GoSub, UpdateNewPositionValues
GuiControl, Main: Move, Image, %newWidth% %newHeight%
;Gui, Main: Hide
Gui, Main: Show, %newX% %newY% %newWidth% %newHeight%, %GuiTitle%
GoSub, viewTitle
; this_id:=WinExist("Ahk_PID " this_pid)
return

UpdateNewPositionValues:
floatFormat:=A_FormatFloat 
SetFormat, float, 0.0
  newX=x%_X%
  if(!_X || _X=-1 || _X="" || _X="ERROR")
    newX:=""
  newY=y%_Y%
  if(!_Y || _Y=-1 || _Y="" || _Y="ERROR")
    newY:=""
  newWidth=w%_Width%
  if(!_Width || _Width=-1 || _Width="" || _Width="ERROR")
    newWidth:=""
  newHeight=h%_Height%
  if(!_Height || _Height=-1 || _Height="" || _Height="ERROR")
    newHeight:=""
SetFormat, float, %A_FormatFloat%
return

MainGuiSize:
    while GetKeyState("LButton", "P")
    {
        
    }
    GoSub, GetCurrentPosition
    new_Width:=A_GuiWidth
    new_Height:=A_GuiHeight
    displayImage:=0
    if(new_Width && new_Height && (new_Width!=_Width || new_Height!=_Height))
        displayImage:=1
    _Width:=new_Width
    _Height:=new_Height
    GoSub, SaveNewPosition
    GoSub, LoadImage
    if(displayImage)
    {
        GoSub, displayImage
        GoSub, LoadImage
    }
Return

OpenFolder:
SplitPath, imageFile, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
Run, % OutDir
SelectFile(imageFile)
return

CopyAsHTML:
HtmlData:= "<IMG src=""data:image/png;base64," Base64ImageData """>"
WinClip.Clear()
WinClip.SetText(HtmlData)
WinClip.SetHTML(HtmlData)
IniWrite, html, %A_ScriptDir%\image.ini, settings, copyDestiny
return

CopyAsMarkdown:
Clipboard:="![img](" . imageFile . ")"
IniWrite, markdown, %A_ScriptDir%\image.ini, settings, copyDestiny
return

CopyAsLatex:
SplitPath, imageFile, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
OutDir:=StrReplace(OutDir,"\","/")
include_graphics=
(
\begin{figure}
\centering
    \includegraphics[width = 0.8\linewidth]{{"%OutDir%/%OutNameNoExt%"}.%OutExtension%}
\caption[Caption LOF]{Caption}
\end{figure}
)
Clipboard:=include_graphics
IniWrite, latex, %A_ScriptDir%\image.ini, settings, copyDestiny
return

CopyToClipboard:
tempfile:=A_ScriptDir . "\temp.png"
nBytes := Base64Dec( Base64ImageData, Bin )
File := FileOpen(tempfile, "w")
File.RawWrite(Bin, nBytes)
File.Close()
pToken := Gdip_Startup()
Gdip_SetBitmapToClipboard(pBitmap := Gdip_CreateBitmapFromFile(tempfile))
Gdip_DisposeImage(pBitmap)
Gdip_Shutdown(pToken)
FileDelete, %tempfile%
IniWrite, clipboard, %A_ScriptDir%\image.ini, settings, copyDestiny
return

ExitApplication:
if A_ExitReason not in Logoff,Shutdown,Exit,Reload
{
    if(force_exit<>1)
    {
        SetTimer, ModalInputOnTop, -50
        msgbox, 4, image.exe,Exit %title%?
        IfMsgBox, No
            return
    }
}
SaveAndExitApplication:
GoSub, SaveAll
GoSub, SelectRight
ExitApp

SaveAll:
GoSub, SaveCurrentPosition
SaveRecentCommands()
if(stackWindows)
    IniDelete, %A_ScriptDir%\image.ini,stackY,%imageFile%
IniWrite, 0, %A_ScriptDir%\image.ini, %imageFile%, opened
return

SaveRecentCommands(command=0)
{
    global recentCommands
    if(command)
        UpdateRecentCommands(command)
    IniDelete, %A_ScriptDir%\image.ini, recents
    for k, v in recentCommands
    {
        IniWrite, %v%, %A_ScriptDir%\image.ini, recents,%k%
    }
    return
}

SaveRecentSessions(command=0)
{
    global recentSessions
    if(command)
        UpdateRecentSessions(command)
    IniDelete, %A_ScriptDir%\image.ini, recent_sessions
    for k, v in recentSessions
    {
        IniWrite, %v%, %A_ScriptDir%\image.ini, recent_sessions,%k%
    }
    return
}

#IfWinActive

+#s::
force_keys:=1
Suspend, Off
SetSystemCursor("IDC_CROSS")
LetUserSelectRect(vWinX1, vWinY1, vWinX2, vWinY2)
RestoreCursors()
if(vWinX1 . vWinY1 = vWinX2 . vWinY2)
    return
force_keys:=0
SS_GDIWidth := vWinX2-vWinX1, SS_GDIHeight := vWinY2-vWinY1, SS_GDIStartX := vWinX1, SS_GDIStartY := vWinY1
GoSub, CaptureRectangleAndOpen
return

LetUserSelectRect(ByRef X1, ByRef Y1, ByRef X2, ByRef Y2)
{
    DetectHiddenWindows, On
    static r := 1
    ; Create the "selection rectangle" GUIs (one for each edge).
    Loop 4 {
        gui, s%A_Index%: -dpiscale
        Gui, s%A_Index%: -Caption +ToolWindow +AlwaysOnTop
        Gui, s%A_Index%: Color, Red
    }
    Gui, s0: -dpiscale
	Gui, s0: -Caption +ToolWindow +AlwaysOnTop +hWndhGuiSel
	Gui, s0: Color, Red
	WinSet, Transparent, 32, % "ahk_id " hGuiSel
    ; Disable LButton.
    Hotkey, If
    Hotkey, *LButton, lusr_return, On
    ; Wait for user to press LButton.
    KeyWait, LButton, D
    ; Get initial coordinates.
    CoordMode, Mouse
    MouseGetPos, xorigin, yorigin
    ; Set timer for updating the selection rectangle.
    SetTimer, lusr_update, 10
    ; Wait for user to release LButton.
    KeyWait, LButton, U
    ; Re-enable LButton.
    Hotkey, *LButton, Off
    ; Disable timer.
    SetTimer, lusr_update, Off
    ; Destroy "selection rectangle" GUIs.
    Loop 4
        Gui, s%A_Index%: Destroy
    Gui, s0: Destroy
    return
 
    lusr_update:
        CoordMode, Mouse
        MouseGetPos, x, y
        if (x = xlast && y = ylast)
            ; Mouse hasn't moved so there's nothing to do.
            return
        if (x < xorigin)
             x1 := x, x2 := xorigin
        else x2 := x, x1 := xorigin
        if (y < yorigin)
             y1 := y, y2 := yorigin
        else y2 := y, y1 := yorigin
        ; Update the "selection rectangle".
        Gui, s1:Show, % "NA X" x1 " Y" y1 " W" x2-x1 " H" r
        Gui, s2:Show, % "NA X" x1 " Y" y2-r " W" x2-x1 " H" r
        Gui, s3:Show, % "NA X" x1 " Y" y1 " W" r " H" y2-y1
        Gui, s4:Show, % "NA X" x2-r " Y" y1 " W" r " H" y2-y1
        Gui, s0:Show, % "X" x1 " Y" y1 " W" x2-x1 " H" y2-y1
    lusr_return:
    return
}
SetSystemCursor( Cursor = "", cx = 0, cy = 0 )
{
	BlankCursor := 0, SystemCursor := 0, FileCursor := 0 ; init

	SystemCursors = 32512IDC_ARROW,32513IDC_IBEAM,32514IDC_WAIT,32515IDC_CROSS
	,32516IDC_UPARROW,32640IDC_SIZE,32641IDC_ICON,32642IDC_SIZENWSE
	,32643IDC_SIZENESW,32644IDC_SIZEWE,32645IDC_SIZENS,32646IDC_SIZEALL
	,32648IDC_NO,32649IDC_HAND,32650IDC_APPSTARTING,32651IDC_HELP

	If Cursor = ; empty, so create blank cursor
	{
		VarSetCapacity( AndMask, 32*4, 0xFF ), VarSetCapacity( XorMask, 32*4, 0 )
		BlankCursor = 1 ; flag for later
	}
	Else If SubStr( Cursor,1,4 ) = "IDC_" ; load system cursor
	{
		Loop, Parse, SystemCursors, `,
		{
			CursorName := SubStr( A_Loopfield, 6, 15 ) ; get the cursor name, no trailing space with substr
			CursorID := SubStr( A_Loopfield, 1, 5 ) ; get the cursor id
			SystemCursor = 1
			If ( CursorName = Cursor )
			{
				CursorHandle := DllCall( "LoadCursor", Uint,0, Int,CursorID )
				Break
			}
		}
		If CursorHandle = ; invalid cursor name given
		{
			Msgbox,, SetCursor, Error: Invalid cursor name
			CursorHandle = Error
		}
	}
	Else If FileExist( Cursor )
	{
		SplitPath, Cursor,,, Ext ; auto-detect type
		If Ext = ico
			uType := 0x1
		Else If Ext in cur,ani
			uType := 0x2
		Else ; invalid file ext
		{
			Msgbox,, SetCursor, Error: Invalid file type
			CursorHandle = Error
		}
		FileCursor = 1
	}
	Else
	{
		Msgbox,, SetCursor, Error: Invalid file path or cursor name
		CursorHandle = Error ; raise for later
	}
	If CursorHandle != Error
	{
		Loop, Parse, SystemCursors, `,
		{
			If BlankCursor = 1
			{
				Type = BlankCursor
				%Type%%A_Index% := DllCall( "CreateCursor"
				, Uint,0, Int,0, Int,0, Int,32, Int,32, Uint,&AndMask, Uint,&XorMask )
				CursorHandle := DllCall( "CopyImage", Uint,%Type%%A_Index%, Uint,0x2, Int,0, Int,0, Int,0 )
				DllCall( "SetSystemCursor", Uint,CursorHandle, Int,SubStr( A_Loopfield, 1, 5 ) )
			}
			Else If SystemCursor = 1
			{
				Type = SystemCursor
				CursorHandle := DllCall( "LoadCursor", Uint,0, Int,CursorID )
				%Type%%A_Index% := DllCall( "CopyImage"
				, Uint,CursorHandle, Uint,0x2, Int,cx, Int,cy, Uint,0 )
				CursorHandle := DllCall( "CopyImage", Uint,%Type%%A_Index%, Uint,0x2, Int,0, Int,0, Int,0 )
				DllCall( "SetSystemCursor", Uint,CursorHandle, Int,SubStr( A_Loopfield, 1, 5 ) )
			}
			Else If FileCursor = 1
			{
				Type = FileCursor
				%Type%%A_Index% := DllCall( "LoadImageA"
				, UInt,0, Str,Cursor, UInt,uType, Int,cx, Int,cy, UInt,0x10 )
				DllCall( "SetSystemCursor", Uint,%Type%%A_Index%, Int,SubStr( A_Loopfield, 1, 5 ) )
				Type = FileCursor
				%Type%%A_Index% := DllCall( "LoadImageW"
				, UInt,0, Str,Cursor, UInt,uType, Int,cx, Int,cy, UInt,0x10 )
				DllCall( "SetSystemCursor", Uint,%Type%%A_Index%, Int,SubStr( A_Loopfield, 1, 5 ) )
			}
		}
	}
}

RestoreCursors()
{
	SPI_SETCURSORS := 0x57
	DllCall( "SystemParametersInfo", UInt,SPI_SETCURSORS, UInt,0, UInt,0, UInt,0 )
}

^#c::
GoSub, SS_CaptureFullWindow
CaptureRectangleAndOpen:
GoSub, SS_CaptureScreenRectangleToClipboard
;MsgBox 64, Window Screenshot Copied, Window Screenshot Copied.
Run, "%A_ScriptFullPath%"
return

SS_CaptureFullWindow: 
WinGetActiveStats, SS_ActiveWindowTitle, SS_GDIWidth, SS_GDIHeight, SS_GDIStartX, SS_GDIStartY 
return

SS_CaptureScreenRectangleToClipboard:
pToken := Gdip_Startup()
pBitmap:=
If (GDIplus_CaptureScreenRectangle(pBitmap, SS_GDIStartX, SS_GDIStartY, SS_GDIWidth, SS_GDIHeight, 0, false) != 0)
   Goto GDIplusError
Gdip_SetBitmapToClipboard(pBitmap)
Gdip_DisposeImage(pBitmap)
Gdip_Shutdown(pToken)
return

GDIplusError: 
If (#GDIplus_lastError != "")
   MsgBox 16, GDIplus Test, Error in %#GDIplus_lastError% (at %step%)
GDIplusEnd: 
GDIplus_Stop() 
Return 

#|:: ; $#| doesn't work with notepad++
ActivateSelf0:
GoSub, SetCurrentDocumentId
ActivateSelf:
WinActivate, % "ahk_pid " . DllCall("GetCurrentProcessId")
WinActivate, % "ahk_id " . this_id
return

!|::
classes:=["AutoHotkeyGUI", "tooltips_class32"]
For k, v In classes
{
    WinGet, id, List, ahk_exe image.exe ahk_class %v%
    Loop, %id%
    {
        next_id := id%A_Index%
        WinRestore, % "ahk_id " next_id
    }
}
return

SetCurrentDocumentId:
Critical
if(WinActive("ahk_pid " . DllCall("GetCurrentProcessId")) || WinActive("ahk_exe image.exe"))
	return
WinGet, currentDocumentId, ID, A
return

#If (WinActive("ahk_pid " . DllCall("GetCurrentProcessId")) && WinActive("ahk_class #32770"))
$Esc::
	GoSub, ExitApplication
return
;$Enter::
;	ControlClick, Button2, A
;return

#If (WinActive("ahk_pid " . DllCall("GetCurrentProcessId")) && !WinActive("ahk_class #32770"))
$Esc::
    GoSub, ExitApplication
return
F5::
    GoSub, LoadImage
return
$o::
    DetectHiddenWindows, On
    CoordMode, Menu, Screen
    Menu Tray, Show, 0, 0
return
$f::
    GoSub, OpenFolder
return
r::
    GoSub, ResetPosition
    GoSub, LoadImage
    GoSub, ResetPosition
    GoSub, LoadImage
    GoSub, DisplayImage
return

!#-::
if(!ratio)
    ratio:=GetCurrentRatio()
if(ratio>0)
    ratio:=ratio-1
GoSub, ResetWithRatio
return

-::
if(!ratio)
    ratio:=GetCurrentRatio()
if(ratio>0)
    ratio:=ratio-1
GoSub, ResizeWithRatio
return

!#+::
if(!ratio)
    ratio:=GetCurrentRatio()
if(ratio<0)
	ratio:=1
if(ratio<8)
    ratio:=ratio+1
GoSub, ResetWithRatio
return

+::
if(!ratio)
    ratio:=GetCurrentRatio()
if(ratio<0)
	ratio:=1
if(ratio<8)
    ratio:=ratio+1
GoSub, ResizeWithRatio
return

GetCurrentRatio()
{
    global this_id
    floatFormat:=A_FormatFloat 
    SetFormat, float, 0.0
    WinGetPos ,,, WindowWidth, WindowHeight, ahk_id %this_id%
    SysGet, Monitor, MonitorWorkArea
    MonitorWidth:=MonitorRight
    ratio:=WindowWidth*8/MonitorWidth
    SetFormat, float, %floatFormat%
    return ratio
}

DockImage:
ratio:=4
GoSub, ResetWithRatio
return

ResizeWithRatio:
GoSub, ResetWidthHeightRatio
GoSub, LoadImage
GoSub, DisplayImage
GoSub, SaveNewPosition
return

ResetWithRatio:
GoSub, ResetWidthHeightRatio
GoSub, DisplayImage
GoSub, ResetXPosition
GoSub, ResetY0Position
GoSub, LoadImage
GoSub, DisplayImage
GoSub, SaveNewPosition
return

^c::
IniRead, copyDestiny, %A_ScriptDir%\image.ini, settings, copyDestiny,clipboard
if(copyDestiny="clipboard" || copyDestiny="ERROR")
{
    GoSub, CopyToClipboard
}
else if (copyDestiny="markdown")
{
    GoSub, CopyAsMarkdown
}
else if (copyDestiny="html")
{
    GoSub, CopyAsHTML
}
else if (copyDestiny="latex")
{
    GoSub, CopyAsLatex
}
return

^r::
    IniWrite, 1, %A_ScriptDir%\image.ini, %imageFile%, reload
    command="%A_ScriptFullPath%" "%imageFile%"
    Run, %command%
    ExitApp
return

^s::
^!s::
altPressed:=GetKeyState("Alt", "P")
IniRead, saveDestiny, %A_ScriptDir%\image.ini, settings, saveDestiny, file
if(saveDestiny=="file")
{
    if(altPressed)
        GoSub, SaveSession
    else
        GoSub, SaveAs
}
else
{
    if(altPressed)
        GoSub, SaveAs
    else
        GoSub, SaveSession
}
return

SaveSession:
; msgbox, 4, ,Save session file?
; IfMsgBox, No
;     Return
SplitPath, imageFile,, OutDir
SplitPath, OutDir,OutFileName
IniRead, lastSessionSaveFolder, %A_ScriptDir%\image.ini, settings, lastSessionSaveFolder, %OutDir%
OutFileName:=OutFileName . ".imgx"
FileSelectFile,saveas,S17,%lastSessionSaveFolder%\%OutFileName%,Save session as...,*.imgx
if ErrorLevel
    return
if(FileExist(saveas))
{
    msgbox, 4, ,File already exists, OVERWRITE?
    IfMsgBox, No
        Return
    FileRecycle, %saveas%
}
SplitPath, saveas,, OutDir
IniWrite, %OutDir%, %A_ScriptDir%\image.ini, settings, lastSessionSaveFolder
WinAlreadyOpen(0)
count:=0
for k, v in GetModuleCommandLineFileHash
{
    IniWrite, %k%,%saveas%,files,%count%
    count:=count+1
}
RebuildRecentSessions(saveas)
return

SaveFolderAsSession:
FileGetAttrib, Attributes, %imagesFolder%
if(InStr(Attributes, "D"))
{
    SplitPath, imagesFolder, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
    saveas:=imagesFolder . "\" . OutFileName . ".imgx"
    FileRecycle, %saveas%
    extensions:="jpg,png,tif,bmp,gif"
    count:=0
    Loop, Files, %imagesFolder%\*
    {
        if A_LoopFileExt in %extensions%
        {
            newImageFile:=A_LoopFileLongPath
            IniWrite, %newImageFile%,%saveas%,files,%count%
            count:=count+1
        }
    }
    RebuildRecentSessions(saveas)
}
return

SaveAs:
    SplitPath, imageFile,OutFileName, OutDir,,OutFileNameNoExt
    is_clipboard_file:=0
    if(OutDir=clipboardDirectory)
    {
        is_clipboard_file:=1
    }
    if(is_clipboard_file)
    {
        IniRead, lastFileSaveFolder, %A_ScriptDir%\image.ini, settings, lastSessionSaveFolder, %OutDir%
        FormatTime, CurrTime,,dMMMyy-HH.mm
        OutFileName:=CurrTime . ".png"
    }
    else
    {
        IniRead, lastFileSaveFolder, %A_ScriptDir%\image.ini, settings, lastFileSaveFolder, %OutDir%
        OutFileName:=OutFileNameNoExt . ".png"
    }
    FileSelectFile,saveas,S17,%lastFileSaveFolder%\%OutFileName%,Save as...,*.png
    if ErrorLevel
        return
    SplitPath, saveas,, OutDir
    IniWrite, %OutDir%, %A_ScriptDir%\image.ini, settings, lastFileSaveFolder
    nBytes := Base64Dec( Base64ImageData, Bin )
    File := FileOpen(saveas, "w")
    File.RawWrite(Bin, nBytes)
    File.Close()
    imagesFolder:=OutDir
    GoSub, SaveFolderAsSession
    if(is_clipboard_file)
    {
        command="%A_ScriptFullPath%" "%saveas%"
        Run, %command%
        ExitApp
    }
return

ExitTimer:
ExitApp
return

^m::
WinMinimize, ahk_pid %this_pid% ahk_class AutoHotkeyGUI
WinMinimize, ahk_pid %this_pid% ahk_class tooltips_class32
next_id:=WinGetNext(0)
if(next_id<>this_id)
    WinActivate, % "ahk_id " . next_id
return

GetGuiIDFromPID(pid)
{
    WinGet, this_id, ID, ahk_pid %pid% ahk_class AutoHotkeyGUI
    return this_id
}

m::
classes:=["AutoHotkeyGUI", "tooltips_class32"]
For k, v In classes
{
    WinGet, id, List, ahk_exe image.exe ahk_class %v%
    Loop, %id%
    {
        next_id := id%A_Index%
        if(next_id<>this_id)
        {
            WinMinimize, % "ahk_id " next_id
            WinMinimize, % "ahk_id " next_id
        }
    }
}
WinMinimize, % "ahk_id " this_id
GoSub, SuspendOff
;SetTimer, SuspendOff, -1000
return

SuspendOff:
Suspend, Off
return

+Left::
Left::
SelectLeft:
shiftPressed:=GetKeyState("Shift", "P") || (A_ThisHotkey=="+Left")
next_id:=WinGetNext(0,shiftPressed)
WinActivate, % "ahk_id " . next_id
return

+Right::
Right::
SelectRight:
shiftPressed:=GetKeyState("Shift", "P") || (A_ThisHotkey=="+Right")
next_id:=WinGetNext(1,shiftPressed)
WinActivate, % "ahk_id " . next_id
return

!Right::
SetTimer, SaveCurrentPosition, -100
_X:=_X+10
newX=x%_X%
if(!_X || _X=-1 || _X="" || _X="ERROR")
    newX:=""
Gui, Main: Show, %newX%
return

!Left::
SetTimer, SaveCurrentPosition, -100
_X:=_X-10
newX=x%_X%
if(!_X || _X=-1 || _X="" || _X="ERROR")
    newX:=""
Gui, Main: Show, %newX%
return

!Up::
SetTimer, SaveCurrentPosition, -100
_Y:=_Y-10
newY=y%_Y%
if(!_Y || _Y=-1 || _Y="" || _Y="ERROR")
    newY:=""
Gui, Main: Show, %newY%
return

!Down::
SetTimer, SaveCurrentPosition, -100
_Y:=_Y+10
newY=y%_Y%
if(!_Y || _Y=-1 || _Y="" || _Y="ERROR")
    newY:=""
Gui, Main: Show, %newY%
return

q::
    IniDelete, %A_ScriptDir%\image.ini,stackY,%imageFile%
return

!#^q::
CloseOthers(0)
return

!#q::
CloseOthers(1)
return

CloseOthers(close_self=0)
{
    global this_id
    WinGet, id, List, ahk_exe image.exe ahk_class AutoHotkeyGUI
    Loop, %id%
    {
        next_id := id%A_Index%
        if(this_id<>next_id)
            WinClose, ahk_id %next_id%
        ; Process, Close , %k%
        ; Process, WaitClose,%k%, 2
    }
    if(close_self)
        GoSub, SaveAndExitApplication
    return
}

|::
ActivateDocument:
if(currentDocumentId)
WinActivate, % "ahk_id " . currentDocumentId
else
{
	Send, !{Esc}
	GoSub, SetCurrentDocumentId
}
return

w::
h::
GoSub, ResetWidthHeight
GoSub, LoadImage
GoSub, DisplayImage
GoSub, SaveNewPosition
return

a::
z::
GoSub, ResetAspectRatio
GoSub, LoadImage
GoSub, DisplayImage
GoSub, SaveNewPosition
return

x::
ResetXPositionAndShow:
GoSub, ResetXPosition
GoSub, LoadImage
GoSub, DisplayImage
GoSub, SaveNewPosition
return

^y::
y::
ResetYPositionAndShow:
GoSub, ResetYPosition
GoSub, LoadImage
GoSub, DisplayImage
GoSub, SaveNewPosition
return

+y::
if(stackWindows)
    IniDelete,%A_ScriptDir%\image.ini,stackY
return

ReadTransparency:
IniRead, transparency, %A_ScriptDir%\image.ini, %imageFile%, transparency, 0
if(transparency<>0 and transparency<>1)
    transparency:=0
return

t::
GoSub, ReadTransparency
ToggleTransparency:
transparency:=!transparency
IniWrite, %transparency%, %A_ScriptDir%\image.ini, %imageFile%, transparency
if(transparency)
    ToolTip, Transparency ON,%toolTipX%,%toolTipY%
else
    ToolTip, Transparency OFF,%toolTipX%,%toolTipY%
SetTimer, viewTitle, -1000
SetTransparency:
    GoSub, ReadTransparency
    if(transparency)
    {
        If(WinActive("ahk_id " . this_id))
        {
            WinSet, Transparent, Off, % "ahk_id " . this_id
            WinSet, ExStyle, -0x20, % "ahk_pid " . DllCall("GetCurrentProcessId")
        }
        else
        {
            WinSet, Transparent, % (255*transparency/3), % "ahk_id " . this_id
            WinSet, ExStyle, +0x20, % "ahk_pid " . DllCall("GetCurrentProcessId")
        }
    }
return

UpdateActive:
    If(WinActive("ahk_id " . this_id))
    {
        Gosub, viewTitle
        SetTimer, SuspendOthers, -10
        ; WinRestore, ahk_id %this_id%
        ; WinActivate, ahk_id %this_id%
        ; WinActivate, ahk_id %this_id%
        GoSub, SetTransparency
    }
    else
    {
        ToolTip
        GoSub, SetTransparency
    }
Return

SuspendOthers:
BroadcastData("suspend")
Suspend, Off
return

BroadcastData(StringToSend)
{
    global this_pid
    WinsGetPIDList()
    WinList:=WinsGetPIDList()
    WinListCount:=WinList._MaxIndex()
    StringToSend:= this_pid . "|" . "suspend"
    Loop, %WinListCount%
    {
        TargetScriptTitle:="ahk_pid " WinList[A_Index]
        Send_WM_COPYDATA(StringToSend, TargetScriptTitle)
    }
    return
}

viewTitle:
SplitPath, imageFile, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
title:=OutFileName
CalculateToolTipDisplayRight(title)
CoordMode, ToolTip, Screen
DetectHiddenWindows, off
WinGetPos, Xt, Yt, Wt, , % "ahk_id " . this_id
toolTipX:=Xt+Wt-tW
toolTipY:=Yt
ToolTip, %title%,%toolTipX%,%toolTipY%
return

CalculateToolTipDisplayRight(CData) {
	global tW
	global tH
    global this_pid

	CoordMode, ToolTip, Screen
	ToolTip, %CData%,,A_ScreenHeight+100
	thisId:=WinExist()
	WinGetPos,,, tW, tH, ahk_class tooltips_class32 ahk_pid %this_pid%
	ToolTip
	Return
}

ModalInputOnTop:
    WinSet, AlwaysOnTop, On, % "ahk_pid " . DllCall("GetCurrentProcessId") . " ahk_class " . "#32770"
Return 

WM_LBUTTONDOWN(wParam, lParam, Msg, hWnd)
{
    GoSub, DragWindow
}

WM_SINK(wParam, lParam, Msg, hWnd)
{
    return 1
}

DragWindow:
CoordMode, Mouse  ; Switch to screen/absolute coordinates.
MouseGetPos, EWD_MouseStartX, EWD_MouseStartY, EWD_MouseWin
WinGetPos, EWD_OriginalPosX, EWD_OriginalPosY,,, ahk_id %EWD_MouseWin%
WinGet, EWD_WinState, MinMax, ahk_id %EWD_MouseWin% 
if EWD_WinState = 0  ; Only if the window isn't maximized
    SetTimer, EWD_WatchMouse, 10 ; Track the mouse as the user drags it.
return

EWD_WatchMouse:
GetKeyState, EWD_LButtonState, LButton, P
if EWD_LButtonState = U  ; Button has been released, so drag is complete.
{
    SetTimer, EWD_WatchMouse, Off
    GoSub, SaveCurrentPosition
    return
}
GetKeyState, EWD_EscapeState, Escape, P
if EWD_EscapeState = D  ; Escape has been pressed, so drag is cancelled.
{
    SetTimer, EWD_WatchMouse, Off
    WinMove, ahk_id %EWD_MouseWin%,, %EWD_OriginalPosX%, %EWD_OriginalPosY%
    return
}
; Otherwise, reposition the window to match the change in mouse coordinates
; caused by the user having dragged the mouse:
CoordMode, Mouse
MouseGetPos, EWD_MouseX, EWD_MouseY
WinGetPos, EWD_WinX, EWD_WinY,,, ahk_id %EWD_MouseWin%
SetWinDelay, -1   ; Makes the below move faster/smoother.
WinMove, ahk_id %EWD_MouseWin%,, EWD_WinX + EWD_MouseX - EWD_MouseStartX, EWD_WinY + EWD_MouseY - EWD_MouseStartY
EWD_MouseStartX := EWD_MouseX  ; Update for the next timer-call to this subroutine.
EWD_MouseStartY := EWD_MouseY
return

WM_RBUTTONDOWN(wParam, lParam)
{
   Menu, Tray, Show
}

Base64Enc( ByRef Bin, nBytes, LineLength := 64, LeadingSpaces := 0 ) { ; By SKAN / 18-Aug-2017
Local Rqd := 0, B64, B := "", N := 0 - LineLength + 1  ; CRYPT_STRING_BASE64 := 0x1
  DllCall( "Crypt32.dll\CryptBinaryToString", "Ptr",&Bin ,"UInt",nBytes, "UInt",0x1, "Ptr",0,   "UIntP",Rqd )
  VarSetCapacity( B64, Rqd * ( A_Isunicode ? 2 : 1 ), 0 )
  DllCall( "Crypt32.dll\CryptBinaryToString", "Ptr",&Bin, "UInt",nBytes, "UInt",0x1, "Str",B64, "UIntP",Rqd )
  If ( LineLength = 64 and ! LeadingSpaces )
    Return B64
  B64 := StrReplace( B64, "`r`n" )        
  Loop % Ceil( StrLen(B64) / LineLength )
    B .= Format("{1:" LeadingSpaces "s}","" ) . SubStr( B64, N += LineLength, LineLength ) . "`n" 
Return RTrim( B,"`n" )    
}

Base64Dec( ByRef B64, ByRef Bin ) {  ; By SKAN / 18-Aug-2017
Local Rqd := 0, BLen := StrLen(B64)                 ; CRYPT_STRING_BASE64 := 0x1
  DllCall( "Crypt32.dll\CryptStringToBinary", "Str",B64, "UInt",BLen, "UInt",0x1
         , "UInt",0, "UIntP",Rqd, "Int",0, "Int",0 )
  VarSetCapacity( Bin, 128 ), VarSetCapacity( Bin, 0 ),  VarSetCapacity( Bin, Rqd, 0 )
  DllCall( "Crypt32.dll\CryptStringToBinary", "Str",B64, "UInt",BLen, "UInt",0x1
         , "Ptr",&Bin, "UIntP",Rqd, "Int",0, "Int",0 )
Return Rqd
}

Base64ToComByteArray( ByRef B64 ) {  ; By SKAN / Created: 21-Aug-2017 / Topic: goo.gl/dyDxBN 
Static CRYPT_STRING_BASE64 := 0x1
Local  Rqd := 0, BLen := StrLen(B64), ByteArray := ""  

  If DllCall( "Crypt32.dll\CryptStringToBinary", "Str",B64, "UInt",BLen, "UInt",CRYPT_STRING_BASE64
              , "UInt",0, "UIntP",Rqd, "Int",0, "Int",0 )
  {
     ByteArray := ComObjArray( 0x11, Rqd ) 
     DllCall( "Crypt32.dll\CryptStringToBinary", "Str",B64, "UInt",BLen, "UInt",CRYPT_STRING_BASE64
         , "Ptr",NumGet( ComObjValue( ByteArray ) + 8 + A_PtrSize ), "UIntP",Rqd, "Int",0, "Int",0 )
  }

Return ByteArray
}

WinAlreadyOpen(selFile)
{
    global GetModuleCommandLineHash
    global GetModuleCommandLineFileHash
    GetModuleCommandLineHash:={}
    GetModuleCommandLineFileHash:={}
    WinList:=WinsGetPIDList()
    WinListCount:=WinList._MaxIndex()
    Loop, %WinListCount%
        GetModuleCommandLine(WinList[A_Index])
    return GetModuleCommandLineFileHash.HasKey(selFile)
}

WinGetNext(dir=0, shiftPressed=0)
{
    global this_pid
    WinList:=WinsGetPIDList()
    WinListCount:=WinList._MaxIndex()
    if(WinListCount=1)
    {
        IniDelete, %A_ScriptDir%\image.ini,stackY
        return -1
    }
    WinListVar:=
	Loop, %WinListCount%
		WinListVar:=WinListVar . WinList[A_Index] . "`n"
    sort, WinListVar, fSortByLastOpenedPID
    ;Tooltip, %WinListVar%
    WinList:=[]
    Loop, Parse, WinListVar, `n
    {
        WinList.Insert(A_LoopField)
        if(A_LoopField=this_pid)
            current_index:=A_Index
    }
    if(!shiftPressed)
    {
        min_offset:=0
        loop
        {
            current_pid:=WinList[Abs(Mod(current_index+min_offset-1+WinListCount+(dir?1:-1),WinListCount))+1]
            WinGet MX, MinMax, % "ahk_pid " current_pid " ahk_class AutoHotkeyGUI"
            if(min_offset>WinListCount || (MX<>-1 && current_pid<>this_pid))
                break
            min_offset:=min_offset+1
        }
        if(min_offset>WinListCount)
            return -1
        else
        {
            WinGet, next_id, ID, ahk_pid %current_pid% ahk_class AutoHotkeyGUI
            return next_id
        }
    }
    else
    {
        tooltip, AAA 
        current_pid:=WinList[Abs(Mod(current_index-1+WinListCount+(dir?1:-1),WinListCount))+1]
        WinGet, next_id, ID, ahk_pid %current_pid% ahk_class AutoHotkeyGUI
        return next_id
    }
}

SortByLastOpenedPID(a1, a2){
    a1p:=a1
    a2p:=a2
    a1:=GetOpenedWindowDate(a1)
    a2:=GetOpenedWindowDate(a2)
    if(a1==a2)
    {
        a1:=a1p
        a2:=a2p
    }
    return a1 < a2 ? -1 : a1 > a2 ? 1 : 0
}

GetOpenedWindowDate(winpid)
{
    pat:=GetModuleCommandLine(winpid)
    imageFile:=RegexReplace(pat,"""(.*?)""(.*?)""(.*?)"".*", "$3")
    if(StrLen(imageFile)<=1)
        imageFile:=pat
    IniRead, LastOpened, %A_ScriptDir%\image.ini, %imageFile%, LastOpened,-1
    return LastOpened
}

GetModuleCommandLine(p_id) {
    global GetModuleCommandLineHash
    global GetModuleCommandLineFileHash
    if(GetModuleCommandLineHash.HasKey(p_id))
    {
        return GetModuleCommandLineHash[p_id]
    }
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ProcessId=" p_id)
    {
        GetModuleCommandLineHash[p_id]:=process.CommandLine
        file:=RegexReplace(process.CommandLine,"""(.*?)""(.*?)""(.*?)"".*", "$3")
        GetModuleCommandLineFileHash[file]:=p_id
		return process.CommandLine
    }
}

WinsGetPIDList(dir=0, exclude_id=0) {
	DetectHiddenWindows, Off
	ListArray:=[]
    WinGet, id, List, ahk_exe image.exe ahk_class AutoHotkeyGUI
    Loop, %id%
    {
		if(!dir)
			index:=A_Index
		else
			index:=myList - A_Index
        next_id := id%index%
        if(exclude_id=next_id)
            continue
        WinGet, process_id, PID, % "ahk_id " next_id
		ListArray.Insert(process_id)
    }
    return ListArray
}

WinIsVisible(ahk_id="A"){
	hWindow:=ahk_id
	if(ahk_id!="A")
	{
		ahk_id := "ahk_id " . ahk_id
	}
	else
	{
		WinGet, hWindow, ID, A
	}
	WinGet, Active_Process, ProcessName, ahk_id %hWindow%
	 WinGet, es, ExStyle, ahk_id %hWindow%
      return !((es & WS_EX_TOOLWINDOW) && !(es & WS_EX_APPWINDOW))
}

WM_SIZE(wParam, lParam)
{
    SetTimer, UpdateSuspended, -100
}

AllMinimized()
{
    global this_id
    WinGet, id, List, ahk_exe image.exe ahk_class AutoHotkeyGUI
    all_minimized:=1
    Loop, %id%
    {
        next_id := id%A_Index%
        if(next_id<>this_id)
        {
            WinGet MMX, MinMax, ahk_id %next_id%
            if(MMX!=-1)
            {
                all_minimized:=0
                break
            }
        }
    }
    return all_minimized
}

UpdateSuspended:
WinGet MMX, MinMax, ahk_id %this_id%
if(MMX=-1)
{
    if(!AllMinimized() && !force_keys)
        Suspend, On
}
else
    Suspend, Off
return

TestActive()
{
	SetTimer, UpdateActive, -100
}

Receive_WM_COPYDATA(wParam, lParam)
{
    StringAddress := NumGet(lParam + 2*A_PtrSize)
    CopyOfData := StrGet(StringAddress)
    OnCommand(CopyOfData)
    return true
}

Send_WM_COPYDATA(ByRef StringToSend, ByRef TargetScriptTitle)
{
    VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
    SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
    NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
    NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)
    Prev_DetectHiddenWindows := A_DetectHiddenWindows
    Prev_TitleMatchMode := A_TitleMatchMode
    DetectHiddenWindows On
    SetTitleMatchMode 2
    SendMessage, 0x4a, 0, &CopyDataStruct,, %TargetScriptTitle%
    DetectHiddenWindows %Prev_DetectHiddenWindows%
    SetTitleMatchMode %Prev_TitleMatchMode%
    return ErrorLevel
}

IsMinimized()
{
    global this_pid
    WinGet MX, MinMax, % "ahk_pid " this_pid " ahk_class AutoHotkeyGUI"
    return MX==-1
}

OnCommand(string)
{
    global this_pid
    global force_keys

    arr:=StrSplit(string, "|")
    sender_pid:=arr[1]
    command:=arr[2]
    if(sender_pid<>this_pid)
    {
        if(command="suspend")
        {
            if(!force_keys)
                Suspend, On
        }
    }
}

SelectFile(file)
{
    StringReplace, file, file,/,\, All
    char=`" ;"
    while(SubStr(file, 1,1)=char)
        file:=Trim(SubStr(file,2,StrLen(file)-1))
    while(SubStr(file, StrLen(file),1)=char)
        file:=Trim(SubStr(file,1,StrLen(file)-1))
    char=`\
    while(SubStr(file, StrLen(file),1)=char)
        file:=Trim(SubStr(file,1,StrLen(file)-1))
    SplitPath, file, name, dir, ext, name_no_ext, drive
    folder:=dir
    wins := ComObjCreate("Shell.Application").windows
    Run, "%folder%"
    if(FileExist(file)){ ;name<>name_no_ext &&
        buscarVentana:=1
        while(buscarVentana){
            For win in wins
            {
                ComObjError(false)
                if(win.document.folder)
                if(win.document.folder.self.path=folder)
                {
                    doc:=win.document
                    buscarVentana:=0
                }
            }
        }
        ComObjError(true)
        items := doc.folder.items
        for item in doc.SelectedItems
        {
            doc.SelectItem(item, 16)
        }
        doc.SelectItem(items.item(name), 16)
        doc.SelectItem(items.item(name), 1)
    }
}