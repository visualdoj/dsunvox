# Sunvox Lib header for Free Pascal

This is FPC header for [Sunvox Lib 2.0e](https://warmplace.ru/soft/sunvox/sunvox_lib.php).
The official header is outdated.

The header [dsunvox.pas](dsunvox.pas) itself is public domain, but not the library.

Examples are also ported and tested.

## Issues

* Tested only on Windows

## API differences

* Additional type `TSunvoxInt` instead of `int` in API calls
* Macro `SV_GET_MODULE_XY` has been renamed to `svUnpackModuleXY` to prevent name conflict with API function `sv_get_module_xy`
* Macro `SV_GET_MODULE_FINETUNE` has been renamed to `svUnpackModuleFinetune` to prevent name conflict with function `sv_get_module_finetune`
* Additional function `svGetLoaderError` instead of printing errors `stdout` which may cause errors in GUI applications
