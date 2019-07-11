FileMD5(path = "", chunkSize = 8) {

	If (ChunkSize < 0 || ChunkSize > 8)
		 ChunkSize := 8

	ChunkSize :=  2 ** (18 + ChunkSize)

	File := DllCall("CreateFile", Str, path, UInt, 0x80000000, Int, 3, Int, 0, Int, 3, Int, 0, Int, 0)
	If (File < 1)
		Return, File

	VarSetCapacity(Buffer, ChunkSize, 0)

	DllCall("GetFileSizeEx", UInt, File, Str, Buffer)
	FileSize := NumGet(Buffer, 0, "Int64")

	VarSetCapacity(MD5_CTX, 104, 0)

	hMod := DllCall("LoadLibrary", Str, "advapi32.dll")
	DllCall("advapi32\MD5Init", Str, MD5_CTX)

	AmountOfChunks := (FileSize // ChunkSize + !! Mod(FileSize, ChunkSize ))
	Loop %AmountOfChunks% {
		DllCall("ReadFile", UInt, File, Str, Buffer, UInt, ChunkSize, UIntP, BytesRead, UInt, 0)
		DllCall("advapi32\MD5Update", Str, MD5_CTX, Str, Buffer, UInt, BytesRead)
	}

	DllCall("advapi32\MD5Final", Str, MD5_CTX)
	DllCall("FreeLibrary", UInt, hMod)
	DllCall("CloseHandle", UInt, File)

	Hex := "123456789ABCDEF0"
	Loop % StrLen(Hex) {
		N := NumGet(MD5_CTX, 87 + A_Index, "Char")
		MD5 := MD5 SubStr(Hex, N >> 4, 1) SubStr(Hex, N & 15, 1)
	}
	Return MD5
}