#NoEnv
#MaxHotkeysPerInterval 200
#SingleInstance force
#KeyHistory 0
ListLines Off
DetectHiddenWindows, on
OnMessage(0x00FF, "InputMessage")
SetStoreCapslockMode, off
SendMode, Input

Gui, Show, Hide x0 y0 h0 w0, AppleWKHelper
HWND := WinExist("AppleWKHelper")

hidMessage := 0
fnPressed := 0

SizeofRawInputDeviceList := A_PtrSize * 2
SizeofRawInputDevice := 8 + A_PtrSize

RIM_TYPEMOUSE := 0
RIM_TYPEKEYBOARD := 1
RIM_TYPEHID := 2

RIDI_DEVICENAME := 0x20000007
RIDI_DEVICEINFO := 0x2000000b

RIDEV_INPUTSINK := 0x00000100

RID_INPUT := 0x10000003

DoCapture := 0


Res := DllCall("GetRawInputDeviceList", "Ptr", 0, "UInt*", Count, UInt, SizeofRawInputDeviceList)
VarSetCapacity(RawInputList, SizeofRawInputDeviceList * Count)

Res := DllCall("GetRawInputDeviceList", "Ptr", &RawInputList, "UInt*", Count, "UInt", SizeofRawInputDeviceList)

rimHIDregistered := 0

Loop %Count%
{
	Handle := NumGet(RawInputList, (A_Index - 1) * SizeofRawInputDeviceList, "UInt")
	Type := NumGet(RawInputList, ((A_Index - 1) * SizeofRawInputDeviceList) + A_PtrSize, "UInt")
	If (Type = RIM_TYPEMOUSE)
		TypeName := "RIM_TYPEMOUSE"
	else If (Type = RIM_TYPEKEYBOARD)
		TypeName := "RIM_TYPEKEYBOARD"
	else If (Type = RIM_TYPEHID)
		TypeName := "RIM_TYPEHID"
	else   
		TypeName := "RIM_OTHER"

	Res := DllCall("GetRawInputDeviceInfo", "Ptr", Handle, "UInt", RIDI_DEVICENAME, "Ptr", 0, "UInt *", nLength)
	VarSetCapacity(Name, (nLength + 1) * 2)
	Res := DllCall("GetRawInputDeviceInfo", "Ptr", Handle, "UInt", RIDI_DEVICENAME, "Str", Name, "UInt*", nLength)

	Res := DllCall("GetRawInputDeviceInfo", "Ptr", Handle, "UInt", RIDI_DEVICEINFO, "Ptr", 0, "UInt *", iLength)
	VarSetCapacity(Info, iLength)
	NumPut(iLength, Info, 0, "UInt")
	
	Res := DllCall("GetRawInputDeviceInfo", "Ptr", Handle, "UInt", RIDI_DEVICEINFO, "UInt", &Info, "UInt *", iLength)

	If (Type = RIM_TYPEHID)
	{
		Vendor := NumGet(Info, 4 * 2, "UShort")
		Product := NumGet(Info, 4 * 3, "UShort")
		Version := NumGet(Info, 4 * 4, "UShort")
		UsagePage := NumGet(Info, (4 * 5), "UShort")
		Usage := NumGet(Info, (4 * 5) + 2, "UShort")
	}

	VarSetCapacity(RawDevice, SizeofRawInputDevice, 0)
	NumPut(RIDEV_INPUTSINK, RawDevice, 4)
	NumPut(HWND, RawDevice, 8)

	If (Type = RIM_TYPEHID && Vendor = 1452  && rimHIDregistered = 0)
	{
		rimHIDregistered := 1
		NumPut(UsagePage, RawDevice, 0, "UShort")
		NumPut(Usage, RawDevice, 2, "UShort")	  
		Res := DllCall("RegisterRawInputDevices", "UInt", &RawDevice, UInt, 1, UInt, SizeofRawInputDevice) 
		If (Res = 0) {
			MsgBox, Failed to register for AWK device!
		ExitApp
        }
	}
}

Count := 1 

InputMessage(wParam, lParam, msg, hwnd)
{
	global hidMessage, RIM_TYPEMOUSE, RIM_TYPEKEYBOARD, RIM_TYPEHID, RID_INPUT

	Res := DllCall("GetRawInputData", "UInt", lParam, "UInt", RID_INPUT, "Ptr", 0, "UInt *", Size, "UInt", 8 + A_PtrSize * 2)
	VarSetCapacity(Buffer, Size)
	Res := DllCall("GetRawInputData", "UInt", lParam, "UInt", RID_INPUT, "Ptr", &Buffer, "UInt *", Size, "UInt", 8 + A_PtrSize * 2)
   
	Type := NumGet(Buffer, 0, "UInt")


	If (Type = RIM_TYPEHID)
	{
		SizeHid := NumGet(Buffer, (8+A_PtrSize*2), "UInt")
		InputCount := NumGet(Buffer, (12+A_PtrSize*2), "UInt")
		Loop %InputCount% {
			Addr := &Buffer + (16+A_PtrSize*2) + ((A_Index - 1) * SizeHid)
			hidMessage := Mem2Hex(Addr, SizeHid)
			ProcessHIDData(wParam, lParam)
		}
	}
	Return
}

Mem2Hex( pointer, len )
{
	multiply := 0x100
	Hex := 0
	Loop, %len%  {
		Hex := Hex * multiply
		Hex := Hex + *Pointer+0
		Pointer ++
	}
	Return Hex 
}

ProcessHIDData(wParam, lParam)
{
  	global hidMessage, fnPressed, ejHoldOn, fnHoldOn

	Transform, FnValue, BitAnd, 0xFF10, hidMessage

	If (FnValue = 0x1110) {
		fnPressed := 1
		SetTimer, fnHoldOnTimer, -200
	} else if (fnPressed = 1) {
		fnPressed := 0
		SetTimer, fnHoldOnTimer, Off
		If fnHoldOn = 1
		{
			fnHoldOn := 0
		} else {
		    If (IME_GET()=0)
		        Send, +^{f}
		    else
		        Send, +^{u}
            SetTimer, OutputCharSetToolTip, -100
		}
	}

  Transform, FnValue, BitAnd, 0xFF08, hidMessage
  
	If (FnValue = 0x1108) {
		If (GetKeyState("LWin") and GetKeyState("Shift"))
			SendMessage, 0x0112, 0xF170, 2,, Program Manager
		else If (GetKeyState("LWin") and GetKeyState("alt") and GetKeyState("Ctrl"))
			Shutdown, 1
		else If (GetKeyState("alt") and GetKeyState("Ctrl"))
			DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
		else If (GetKeyState("LWin") and GetKeyState("Ctrl"))
			Shutdown, 2
		else If (GetKeyState("LWin"))
		{
			SetTimer, ChangeShutdownButtonNames, 10 
			MsgBox, 262691, 　, 確定要現在關機嗎？
			IfMsgBox Yes
				Shutdown, 2
			IfMsgBox No
				Shutdown, 1
		}
		else
		SetTimer, ejHoldOnTimer, -400
	} else {
		SetTimer, ejHoldOnTimer, Off
		If ejHoldOn = 1
		{
			ejHoldOn := 0
			DllCall("LockWorkStation")
			SendMessage, 0x0112, 0xF170, 2,, Program Manager
		}
	}
}

IME_GET()
{
    SetEnv, WinTitle, A
    WinGet, hWnd, ID, %WinTitle%
    DefaultIMEWnd := DllCall("imm32\ImmGetDefaultIMEWnd", Uint, hWnd, Uint)
    DetectSave := A_DetectHiddenWindows
    DetectHiddenWindows, ON
    SendMessage, 0x283, 0x001, 0, , ahk_id %DefaultIMEWnd%
    DetectHiddenWindows, %DetectSave%
    Return, ErrorLevel
}

FocusedControl_GET(Option := "")
{
    WinhWnd := WinExist("A")
    ControlGetFocus, FocusedControl, ahk_id %WinhWnd%
    If Option = ClassNN
        Return, FocusedControl
    If Option = Text
{
        ControlGet, FocusedControlId, Hwnd, , %FocusedControl%, ahk_id %WinhWnd%
        ControlGetText, FocusedControlText, , ahk_id %FocusedControlId%
        Return, FocusedControlText
}
}

ChangeShutdownButtonNames: 
IfWinNotExist, 　
	Return
SetTimer, ChangeShutdownButtonNames, Off 
WinActivate 
ControlSetText, Button1, 重新開機
ControlSetText, Button2, 關機
Return

fnHoldOnTimer:
    fnHoldOn := 1
Return

ejHoldOnTimer:
    ejHoldOn := 1
Return

OutputCharSetToolTip:
    if (IME_GET()=0) {
        ToolTip, Ａ, A_CaretX, A_CaretY + 20
    } else {
        RegRead, CHOutputCharSet, HKEY_CURRENT_USER\Software\Microsoft\InputMethod\Settings\CHS, Output CharSet
        if (CHOutputCharSet = 1)
            ToolTip, 繁, A_CaretX, A_CaretY + 20
        else
            ToolTip, 简, A_CaretX, A_CaretY + 20
    }
    SetTimer, RemoveToolTip, -1000
Return

RemoveToolTip:
    ToolTip
Return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

~$LWin::
    Send, {vkE8}
Return

Alt::
Return

Capslock::
    KeyWait, CapsLock
    If (A_TimeSinceThisHotkey > 500)
        SetTimer, SendCapslock, -1
    Else
        GetKeyState, Mode, CapsLock, T
        If (Mode="D")
            SetTimer, SendCapslock, -1
        Else {
            Send, {Shift}
            SetTimer, OutputCharSetToolTip, -100
        }
Return

SendCapslock:
    Send, {CapsLock}
Return

^r::
    Send, {f5}
Return

^+r::
    Send, ^{f5}
Return

+#^3::
    Send, {PrintScreen}
Return

$+^3::
    Send, #{PrintScreen}
Return

+#^4::
    Send, !{PrintScreen}
Return

$+^4::
    Send, +#{s}
Return

^Left::
    Send, {Home}
Return

^Right::
    Send, {End}
Return

^Up::
    Send, ^{Home}
Return

^Down::
    Send, ^{End}
Return

!Left::
    Send, ^{Left}
Return

!Right::
    Send, ^{Right}
Return

!BS::
    Send, ^{BS}
Return

+!Left::
    Send, +^{Left}
Return

+!Right::
    Send, +^{Right}
Return

+!Up::
    Send, +^{Up}
Return

+!Down::
    Send, +^{Down}
Return

+^Left::
    Send, +{Home}
Return

+^Right::
    Send, +{End}
Return

+^Up::
    Send, +^{Home}
Return

+^Down::
    Send, +^{End}
Return

^m::
    WinGet, MinOrMax, MinMax, A
    If (MinOrMax=-1)
        WinRestore, A
    Else
        WinMinimize, A
Return

!^m::
    WinGet, Active_exe, ProcessName, A
    GroupAdd, Active_exe_Group, ahk_exe %Active_exe%
    WinMinimize, ahk_group Active_exe_Group
Return

#^f::
    WinGet, active_id, ID, A
    if IsFullDisplay(active_id)
        Send, {f11}
    else {
        Send, {f11}
        Sleep 100
        if !(IsFullDisplay(active_id)) {
            WinGet, MinOrMax, MinMax, A
            If (MinOrMax=0)
                WinMaximize, A
            If (MinOrMax=1)
                WinRestore, A
        }
    }
Return

IsFullDisplay(hWnd) {
    Local
    hMon := DllCall("MonitorFromWindow", "Ptr",hWnd, "Int",0x2, "Ptr") ; MONITOR_DEFAULTTONEAREST, 
    VarSetCapacity(MONITORINFO,40,0), VarSetCapacity(WINDOWINFO,60,0), VarSetCapacity(RECT,16), 
    NumPut(40, MONITORINFO, "Int"), DllCall("GetMonitorInfo", "Ptr",hMon, "Ptr",&MONITORINFO), 
    NumPut(60, WINDOWINFO, "Int"), DllCall("GetWindowInfo", "Ptr",hWnd, "Ptr",&WINDOWINFO), 
    Style:=NumGet(WINDOWINFO, 36, "UInt"),  WS_CAPTION:=0xC00000, WS_THICKFRAME:=0x40000
    Return ( DllCall("SubtractRect", "Ptr",&RECT, "Ptr",&MONITORINFO+04, "Ptr",&WINDOWINFO+04) = 0
    ? ( (Style & WS_CAPTION) = 0 ? True : (Style & WS_THICKFRAME) = 0 ? True : False ) : False )
}

!^h::
    WinGet, Active_ID, ID, A
    Send, #{d}
    WinRestore, ahk_id %Active_ID%
Return

^q::
    WinGet, Active_exe, ProcessName, A
    GroupAdd, Active_exe_Group, ahk_exe %Active_exe%
    WinClose, ahk_group Active_exe_Group
    WinWaitClose, ahk_exe %Active_exe%
    Process, Close, %Active_exe%
Return

+!^v::
    ClipboardTemp := ClipboardAll
    Clipboard := Clipboard
    Send, ^{v}
    Sleep 100
    Clipboard := ClipboardTemp
Return

^f3::
    Send, #{d}
Return

+!f11::
    Send, {Volume_Down}
Return

+!f12::
    Send, {Volume_Up}
Return

$^Tab::
    Send, {Alt down}{Tab}
    Keywait Control
    Send, {Alt up}
Return

$^+Tab::
    Send, {Alt down}{Shift down}{Tab}
    Keywait Control
    Send, {Alt up}{Shift up}
Return

$#Tab::
    Send, {Control down}{Tab}
    Keywait LWin
    Send, {Control up}
Return

$#+Tab::
    Send, {Control down}{Shift down}{Tab}
    Keywait LWin
    Send, {Control up}{Shift up}
Return

!Tab::
    Send, {Tab}
Return

!+Tab::
    Send, +{Tab}
Return

#^q::
    DllCall("LockWorkStation")
Return

+^q::
    Shutdown, 0
Return

^!Esc::
    Send, ^+{Esc}
Return

^!+Esc::
WinGet, Active_ID, PID, A
run, taskkill /PID %Active_ID% /F,,Hide
Return

^Space::
If WinActive("ahk_exe SearchHost.exe ahk_class Windows.UI.Core.CoreWindow")
    Send, {Esc}
Else
    Send, #{s}
Return

#Space::
    Send, {Shift}
    SetTimer, OutputCharSetToolTip, -100
Return

^#Space::
    Send, #{.}
Return

!Space::
    Send,  
Return

!-::
    Send, –
Return

+!-::
    Send, —
Return

!=::
    Send, ≠
Return

+!=::
    Send, ±
Return

!/::
    Send, ÷
Return

+!/::
    Send, ¿
Return

!,::
    Send, ≤
Return

!.::
    Send, ≥
Return

+!,::
    Send, «
Return

+!.::
    Send, »
Return

+!`::
    Send, ≈
Return

!y::
    Send, ¥
Return

#If (WinActive("ahk_exe Weixin.exe") and (IME_GET()!=0))

+`::
    ClipboardTemp := ClipboardAll
    clipboard := "～"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+{::
    ClipboardTemp := ClipboardAll
    clipboard := "「"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+}::
    ClipboardTemp := ClipboardAll
    clipboard := "」"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!{::
    ClipboardTemp := ClipboardAll
    clipboard := "『"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!}::
    ClipboardTemp := ClipboardAll
    clipboard := "』"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!<::
    ClipboardTemp := ClipboardAll
    clipboard := "〈"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!>::
    ClipboardTemp := ClipboardAll
    clipboard := "〉"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!9::
    ClipboardTemp := ClipboardAll
    clipboard := "｟"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!0::
    ClipboardTemp := ClipboardAll
    clipboard := "｠"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

![::
    ClipboardTemp := ClipboardAll
    clipboard := "［"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!]::
    ClipboardTemp := ClipboardAll
    clipboard := "］"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!\::
    ClipboardTemp := ClipboardAll
    clipboard := "､"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!,::
    ClipboardTemp := ClipboardAll
    clipboard := "⇒"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!.::
    ClipboardTemp := ClipboardAll
    clipboard := "｡"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

`::
    ClipboardTemp := ClipboardAll
    clipboard := "・"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!`::
    ClipboardTemp := ClipboardAll
    clipboard := "･"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!Space::
    ClipboardTemp := ClipboardAll
    clipboard := "　"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!Space::
    ClipboardTemp := ClipboardAll
    clipboard := "█"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+\::
    ClipboardTemp := ClipboardAll
    clipboard := "｜"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!\::
    ClipboardTemp := ClipboardAll
    clipboard := "￨"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!-::
    ClipboardTemp := ClipboardAll
    clipboard := "－"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!-::
    ClipboardTemp := ClipboardAll
    clipboard := "＿"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!=::
    ClipboardTemp := ClipboardAll
    clipboard := "＋"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!=::
    ClipboardTemp := ClipboardAll
    clipboard := "＝"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+7::
    ClipboardTemp := ClipboardAll
    clipboard := "＆"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!8::
    ClipboardTemp := ClipboardAll
    clipboard := "×"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!6::
    ClipboardTemp := ClipboardAll
    clipboard := "⋯⋯"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!+"::
    ClipboardTemp := ClipboardAll
    clipboard := "〝〞"
    Send, ^{v}
    Send, {Left}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!;::
    ClipboardTemp := ClipboardAll
    clipboard := "｢｣"
    Send, ^{v}
    Send, {Left}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!'::
    ClipboardTemp := ClipboardAll
    clipboard := "❝❞"
    Send, ^{v}
    Send, {Left}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+4::
    ClipboardTemp := ClipboardAll
    clipboard := "¥"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

#If (WinActive("ahk_exe Weixin.exe") and (IME_GET()!=0) & !(A_PriorKey >= "0" && A_PriorKey <= "9"))

/::
    ClipboardTemp := ClipboardAll
    clipboard := "／"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

#If (WinActive("ahk_exe Weixin.exe") and (IME_GET()!=0) & (PriorKeyIsNum = 1) & ((A_PriorKey = "LShift") or (A_PriorKey = "RShift")))

+;::
    ClipboardTemp := ClipboardAll
    clipboard := ":"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
    PriorKeyIsNum := 0
Return

+-::
    ClipboardTemp := ClipboardAll
    clipboard := "−"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
    PriorKeyIsNum := 0
Return

#If (WinActive("ahk_exe Weixin.exe") and (IME_GET()!=0) & ((PriorKeyIsNum != 1) or ((A_PriorKey != "LShift") & (A_PriorKey != "RShift"))))

+-::
    ClipboardTemp := ClipboardAll
    clipboard := "⸺"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

#If WinActive("ahk_exe Weixin.exe")

!Space::
    ClipboardTemp := ClipboardAll
    clipboard := " "
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!-::
    ClipboardTemp := ClipboardAll
    clipboard := "–"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!-::
    ClipboardTemp := ClipboardAll
    clipboard := "—"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!=::
    ClipboardTemp := ClipboardAll
    clipboard := "≠"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!=::
    ClipboardTemp := ClipboardAll
    clipboard := "±"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!/::
    ClipboardTemp := ClipboardAll
    clipboard := "÷"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!/::
    ClipboardTemp := ClipboardAll
    clipboard := "¿"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!,::
    ClipboardTemp := ClipboardAll
    clipboard := "≤"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!.::
    ClipboardTemp := ClipboardAll
    clipboard := "≥"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!,::
    ClipboardTemp := ClipboardAll
    clipboard := "«"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!.::
    ClipboardTemp := ClipboardAll
    clipboard := "»"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

+!`::
    ClipboardTemp := ClipboardAll
    clipboard := "≈"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

!y::
    ClipboardTemp := ClipboardAll
    clipboard := "¥"
    Send, ^{v}
    Sleep, 50
    Clipboard := ClipboardTemp
Return

#If (IME_GET()!=0)

~Shift::
    If ((A_PriorKey != "LShift") & (A_PriorKey != "RShift"))
    {
        if (A_PriorKey >= "0" && A_PriorKey <= "9")
            PriorKeyIsNum := 1
        else
            PriorKeyIsNum := 0
    }
Return

+`::
    Send, ～
Return

+{::
    Send, 「
Return

+}::
    Send, 」
Return

+!{::
    Send, 『
Return

+!}::
    Send, 』
Return

+!<::
    Send, 〈
Return

+!>::
    Send, 〉
Return

+!9::
    Send, ｟
Return

+!0::
    Send, ｠
Return

![::
    Send, ［
Return

!]::
    Send, ］
Return

!\::
    Send, ､
Return

!,::
    Send, ⇒
Return

!.::
    Send, ｡
Return

`::
    Send, ・
Return

!`::
    Send, ･
Return

!Space::
    Send, 　
Return

+!Space::
    Send, █
Return

+\::
    Send, ｜
Return

+!\::
    Send, ￨
Return

!-::
    Send, －
Return

+!-::
    Send, ＿
Return

+!=::
    Send, ＋
Return

!=::
    Send, ＝
Return

+7::
    Send, ＆
Return

+!8::
    Send, ×
Return

+!6::
    Send, ⋯⋯
Return

!+"::
    Send, 〝〞
    Send, {Left}
Return

!;::
    Send, ｢｣
    Send, {Left}
Return

!'::
    Send, ❝❞
    Send, {Left}
Return

+4::
    Send, ¥
Return

#Space::
    Send, +^{f}
    SetTimer, OutputCharSetToolTip, -100
Return

#If ((IME_GET()!=0) & !(A_PriorKey >= "0" && A_PriorKey <= "9"))

/::
    Send, ／
Return

#If ((IME_GET()!=0) & (PriorKeyIsNum = 1) & ((A_PriorKey = "LShift") or (A_PriorKey = "RShift")))

+;::
    Send, {Text}:
    PriorKeyIsNum := 0
Return

+-::
    Send, −
    PriorKeyIsNum := 0
Return

#If ((IME_GET()!=0) & ((PriorKeyIsNum != 1) or ((A_PriorKey != "LShift") & (A_PriorKey != "RShift"))))

+-::
    Send, ⸺
Return

#If fnPressed = 1

BS::
	Send, {Delete}
Return

UP::
	Send, {PgUp}
Return

Down::
	Send, {PgDn}
Return

Left::
	Send, ^{Home}
Return

Right::
	Send, ^{End}
Return

Space::
	Send, #{.}
Return

~#Left::
~#Right::
    If (A_PriorHotkey = "~$LWin")
        FirstWinArrow := 1
Return

#Up::
    If ((FirstWinArrow = 1) & (A_PriorHotkey = "~#Left" or A_PriorHotkey = "~#Right"))
    {
        Send, {LWin down}{Up}
        FirstWinArrow := 0
    } else {
        Send, {LAlt down}{LWin down}{Up}
        FirstWinArrow := 0
        KeyWait, Up
        Send, {LAlt up}
    }
Return

#Down::
    If ((FirstWinArrow = 1) & (A_PriorHotkey = "~#Left" or A_PriorHotkey = "~#Right"))
    {
        Send, {LWin down}{Down}
        FirstWinArrow := 0
    } else {
        Send, {LAlt down}{LWin down}{Down}
        FirstWinArrow := 0
        KeyWait, Down
        Send, {LAlt up}
    }
Return

#f::
    WinGet, MinOrMax, MinMax, A
    If (MinOrMax=0)
        WinMaximize, A
    If (MinOrMax=1)
        WinRestore, A
Return

#r::
	WinRestore, A
Return

#c::
    WinGetPos, , , CenterWinWidth, CenterWinHeight, A
    CenterX := (A_ScreenWidth - CenterWinWidth) // 2
    CenterY := (A_ScreenHeight - CenterWinHeight) // 2
    WinMove, A, , CenterX, CenterY
return

#If fnPressed != 1

F1::
	Send, +{f1}
Return

F2::
	Send, +{f2}
Return

F3::
	Send, #{Tab}
Return

F4::
	Send, +{f4}
Return

F5::
	Send, #{h}
Return

F6::
	Send, +{f6}
Return

F7::
	Send, {Media_Prev}
Return

F8::
	Send, {Media_Play_Pause}
Return

F9::
	Send, {Media_Next}
Return

F10::
	Send, {Volume_Mute}
Return

F11::
	Send, {Volume_Down 3}
Return

F12::
	Send, {Volume_Up 3}
Return

#Up::
#Down::
	Send, #{Tab}
Return

#Left::
	Send, ^#{Left}
Return

#Right::
	Send, ^#{Right}
Return

#If WinActive("ahk_exe explorer.exe")

^q::
    Process, Close, explorer.exe
Return

$Enter::
$NumpadEnter::
    If (InStr(FocusedControl_GET("ClassNN"), "DirectUIHWND2") = 1) or ((InStr(FocusedControl_GET("ClassNN"), "SysTreeView321") = 1) & (InStr(FocusedControl_GET("Text"), "导航窗格") = 1)) or ((InStr(FocusedControl_GET("ClassNN"), "SysListView321") = 1) & (InStr(FocusedControl_GET("Text"), "FolderView") = 1))
        Send, {f2}
    Else
        Send, {Enter}
Return

#If WinActive("ahk_exe explorer.exe ahk_class CabinetWClass") or WinActive("ahk_exe explorer.exe ahk_class Progman") or WinActive("ahk_exe explorer.exe ahk_class WorkerW") or (InStr(FocusedControl_GET("ClassNN"), "DirectUIHWND") = 1) or ((InStr(FocusedControl_GET("ClassNN"), "SysTreeView321") = 1) & (InStr(FocusedControl_GET("Text"), "导航窗格") = 1)) or ((InStr(FocusedControl_GET("ClassNN"), "SysListView321") = 1) & (InStr(FocusedControl_GET("Text"), "FolderView") = 1))

^o::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
{
        Send, {Enter}
        Send, {Enter}
}
    Else
{
        Keywait, Ctrl
        Send, {Enter}
}
Return

#^o::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, ^{Enter}
    Send, ^{Enter}
Return

^i::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, {Enter}
    Send, !{Enter}
Return

^d::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, {Enter}
    Send, ^{c}
    Send, ^{v}
Return

^BS::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, {Enter}
    Send, {Del}
Return

!^BS::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, {Enter}
    Keywait, Ctrl
    Send, +{Del}
Return

+^BS::
    MsgBox, 49, 垃圾桶, 確定要永久清除「垃圾桶」裏的項目嗎？
        IfMsgBox OK
            FileRecycleEmpty
Return

^Up::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, ^{Home}
    Else
    If WinActive("ahk_exe explorer.exe ahk_class Progman") or WinActive("ahk_exe explorer.exe ahk_class WorkerW")
        Run, Explorer
    Else
        Send, !{Up}
Return

^Down::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, ^{End}
    Else
{
    Keywait, Ctrl
    Send, {Enter}
}
Return

#^n::
    If (InStr(FocusedControl_GET("ClassNN"), "Edit") = 1)
        Send, {Enter}
    ClipboardTemp := ClipboardAll
    clipboard := ""
    Send, ^{c}
    ClipWait, 1
    clipboard_Array :=StrSplit(clipboard, "`n")
    FilePath := clipboard_Array[1]
    SplitPath, FilePath, , FileDir
    NewFolderSum := 1
    loop
{
    If (NewFolderSum = 1)
        NewFolder := "包含選中項目的文件夾"
    Else
        NewFolder := "包含選中項目的文件夾 " NewFolderSum
    If (FileExist(FileDir "\" NewFolder), "D")
    NewFolderSum := NewFolderSum + 1
    Else
{
        FileCreateDir, %FileDir%\%NewFolder%
        Loop, parse, clipboard, `n, `r
{
        Loop, %A_LoopField%, 2
{
            FileMoveDir, %A_LoopFileFullPath%, %FileDir%\%NewFolder%\%A_LoopFileName%
            If ErrorLevel
                MsgBox, 16, 文件夾正在使用, 無法移動 %A_LoopFileFullPath%`n`n請關閉該文件夾内的文件並重試。
}
        FileMove, %A_LoopField%, %FileDir%\%NewFolder%
        If ErrorLevel
            MsgBox, 16, 文件正在使用, 無法移動 %A_LoopField%`n`n請關閉該文件並重試。
}
        Send, {f5}
        NewFolderSum := 0
        Clipboard := ClipboardTemp
        Sleep, 100
        Send, %NewFolder%
        Send, {f2}
        Return
}
}
Return

+^.::
    RegRead, ValorHidden,  HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced, Hidden
    If ValorHidden =  2
        RegWrite,  REG_DWORD, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced, Hidden,  1
    Else
        RegWrite,  REG_DWORD, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced, Hidden,  2
    Send, {f5}
Return

^,::
    If WinActive("ahk_class CabinetWClass")
{
        Send, !{t}
        Send, {o}
}
    Else
        Send, ^{,}
Return

^Enter::
Return

+Enter::
Return

!Enter::
Return

#If WinActive("ahk_exe notepad.exe")

+^z::
    Send, ^{z}
Return

^n::
    Send, +^{n}
Return

^f::
    Send, ^{h}
Return

^t::
    Send, !{o}
    Send, {f}
Return

#If WinActive("ahk_exe Notepad2.exe")

^n::
    Send, !{0}
Return

^f::
    Send, ^{h}
Return

^t::
    Send, !{f12}
Return

^0::
    Send, ^{\}
Return

+^s::
    Send, {f6}
Return

+BS::
    Send, ^{h}
Return

#If WinActive("ahk_exe foobar2000.exe")

^w::
    PostMessage, 0x112, 0xF060,,, A
Return

^q::
    Send, !{f4}
Return

#If !(WinActive("ahk_exe msedge.exe") or WinActive("ahk_exe firefox.exe"))

$^h::
    WinGet, Active_ID, ID, A
    WinSet, Transparent, 0, ahk_id %Active_ID%
    WinMinimize, ahk_id %Active_ID%
    WinSet, Transparent, 255, ahk_id %Active_ID%
    WinSet, Transparent, Off, ahk_id %Active_ID%
Return

#If WinActive("CWebviewHostWnd ahk_class CWebviewControlHostWnd ahk_exe wechat.exe")

^w::
    WinClose, 微信 ahk_class WeChatMainWndForPC ahk_exe wechat.exe
Return

#If !(WinActive("ahk_exe msedge.exe") or WinActive("ahk_exe FontLab VI.exe") or WinActive("ahk_exe FontLab 7.exe") or WinActive("ahk_exe FontLab 8.exe") or WinActive("ahk_exe Studio 5.exe") or WinActive("ahk_exe Explorer.exe ahk_class Progman") or WinActive("ahk_exe Explorer.exe ahk_class WorkerW") or WinActive("ahk_exe Explorer.exe ahk_class Shell_TrayWnd") or WinActive("ahk_exe PowerToys.PowerLauncher.exe") or WinActive("ahk_exe firefox.exe"))

^w::
    WinClose, A
Return

#If WinActive("ahk_exe wechat.exe") or WinActive("ahk_exe Weixin.exe") or WinActive("ahk_exe TIM.exe") or WinActive("ahk_exe WXWork.exe") or WinActive("ahk_exe Xmind.exe")

!Enter::
    Send, ^{Enter}
Return

Space::
    If WinActive("图片查看")
        Send, {Esc}
    Else
        Send, {Space}
Return

#If WinActive("ahk_exe SumatraPDF.exe")

^s::
    Send, +^{s}
Return

+^s::
    Send, ^{s}
Return
