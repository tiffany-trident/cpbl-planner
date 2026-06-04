' Wrapper used by Task Scheduler to run update-scores.bat with no visible window.
Set sh = CreateObject("WScript.Shell")
sh.Run """C:\Trident\AI Work\baseball plan\scripts\update-scores.bat""", 0, True
