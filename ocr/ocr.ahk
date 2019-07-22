#Include CLR.ahk

SetWorkingDir, %A_ScriptDir%
CLR_Start()
asm := CLR_LoadLibrary("ocr.dll")
global ocr := asm.CreateInstance("ocr.Class1")
imageFile:=A_ScriptDir . "\" . "image.png"
text:=ocr.GetText(imageFile)
msgbox, % text