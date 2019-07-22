cd ocr/bin/Debug/net461/
xcopy "Tesseract.dll" "..\..\..\..\" /y
xcopy "ocr.dll" "..\..\..\..\" /y
xcopy "System.Drawing.Common.dll" "..\..\..\..\" /y
xcopy "RGiesecke.DllExport.Metadata.dll" "..\..\..\..\" /y
echo D | xcopy "x64" "..\..\..\..\x64" /s /e /y
xcopy "tessdata" "..\..\..\..\tessdata" /s /e /y
cd ../../../../