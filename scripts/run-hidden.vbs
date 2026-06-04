' Wrapper used by Task Scheduler to run update-scores.bat with no visible window.
' WScript.Quit propagates bat exit code so Task Scheduler sees real failures (otherwise everything looks like 0x0).
Set sh = CreateObject("WScript.Shell")
ec = sh.Run("""C:\Trident\AI Work\baseball plan\scripts\update-scores.bat""", 0, True)
WScript.Quit ec
