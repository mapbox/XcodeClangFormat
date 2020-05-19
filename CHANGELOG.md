## 1.1

Released on May 19, 2020.

- Upgraded Clang to 10.0.0
- Fixed configure script to work in directories that contain spaces
- Added detection of source code type: clang-format can now apply different formatting to C/C++, Objective-C/C++, Java and JavaScript
- Changed patch application to individual lines rather than replacing the whole buffer. This preserves selections and breakpoints much better. Note that they are still removed in situations, e.g. when the code around the breakpoint is changed.
- Added command to format the entire file, rather than just the selection
- Renamed the existing command to "Format Selection". **This means you'll have to change your shortcut definitions**

## 1.0

Released on Sep 13, 2016.

- Initial version
