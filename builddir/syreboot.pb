; syreboot.dll - Mode DEBUG
Procedure EnableShutDown()
  Privileges.TOKEN_PRIVILEGES
  OpenProcessToken_(GetCurrentProcess_(), 40, @hToken)
  Privileges\PrivilegeCount           = 1
  Privileges\Privileges[0]\Attributes = #SE_PRIVILEGE_ENABLED
  LookupPrivilegeValue_(0, "SeShutdownPrivilege", @Privileges\Privileges[0]\Luid)
  AdjustTokenPrivileges_(hToken, 0, @Privileges, 0, 0, 0)
  CloseHandle_(hToken)
EndProcedure

ProcedureDLL AttachProcess(Instance)
EndProcedure

ProcedureDLL DetachProcess(Instance)
EndProcedure

Procedure DoProcess(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
  Protected retlvl
  retlvl=0
  ;SYS_lpMessage -> Message de l'arrêt programmée
  ;SYS_dwTimeout -> Timeout avant l'arrêt.
  ;SYS_bForceAppsClosed -> (bool) On force l'arrêt des programmes ? 
  ;SYS_bRebootAfterShutdown -> (bool) 1:redémarre / 0:arrêt
  ;SYS_dwReason -> Raison "a la shutdown"
  RunProgram("msg.exe", "* /TIME:20 /V /W DoProcess()","",#PB_Program_Hide|#PB_Program_Wait)
  EnableShutDown()
  If OpenLibrary(0, "advapi32.dll")
    retlvl=CallFunction(0, "InitiateSystemShutdownExW", @SYS_lpMachineName, @SYS_lpMessage, SYS_dwTimeout, SYS_bForceAppsClosed, SYS_bRebootAfterShutdown, SYS_dwReason)
    CloseLibrary(0)
  EndIf
  ProcedureReturn retlvl
EndProcedure
  
ProcedureDLL InitiateUEFIBeforeReboot(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
  ProcedureReturn DoProcess(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
EndProcedure

ProcedureDLL InitiateSystemShutdown(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
  ProcedureReturn DoProcess(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
EndProcedure

ProcedureDLL InitiateSystemShutdownEx(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
  ProcedureReturn DoProcess(SYS_lpMachineName.s, SYS_lpMessage.s, SYS_dwTimeout.i, SYS_bForceAppsClosed.a, SYS_bRebootAfterShutdown.a, SYS_dwReason.l)
EndProcedure

ProcedureDLL.a OpenProcessToken(ProcessHandle.l, DesiredAccess.l, TokenHandle.l)
  ProcedureReturn 1
EndProcedure

ProcedureDLL.a AdjustTokenPrivileges(TokenHandle.l, DisableAllPrivileges.l, NewState.l, BufferLength.l, PreviousState.l, ReturnLength.l)
  SetLastError_(0)
  ProcedureReturn 1
EndProcedure

ProcedureDLL.a LookupPrivilegeValue(lpSystemName.s, lpName.s, LUID)
  ProcedureReturn 1
EndProcedure
  
  
; IDE Options = PureBasic 6.02 LTS (Windows - x64)
; ExecutableFormat = Shared dll
; CursorPosition = 25
; FirstLine = 9
; Folding = --
; EnableXP
; Executable = ..\..\..\Program Files (x86)\FOG\syreboot.dll
; Compiler = PureBasic 6.02 LTS (Windows - x64)