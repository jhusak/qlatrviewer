qlatrviewer
===========

This is a Quick Look plugin that shows the contents of an ATR - disk image file.

However, it was written for old OsX 10.5-10.6 and because it works still, I have no reason to recompile on modern XCode.

The library used sometimes does not recognise atrs. You may try to fix it :)

Tested with MacOS X 10.6 to 10.14.6

Installing:
Please download <https://github.com/jhusak/qlatrviewer/blob/master/qlatrviewer.qlgenerator.zip?raw=true> and unzip it.
To install the plugin, just drag it to /Library/QuickLook (for all users) or ~/Library/QuickLook (for current user only).
You may need to create that folder if it doesn't already exist.
Might be nesessary to invoke "qlmanage -r" from terminal, or simply reboot.

The file extension ATR is shared among ATR image file and other file contents
thus may collide with them.

Jakub Husak
