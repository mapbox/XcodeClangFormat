# XcodeClangFormat

### [⚙ Download Latest Release](https://github.com/mapbox/XcodeClangFormat/releases/latest)

This plugin written for Xcode 8's new plugin infrastructure uses Clang's `libclangFormat` library to format code according to a `.clang-format` file.

Open the app, select a predefined style, or open the `.clang-format` file from your project:

![](screenshot-config.png)

Then, use the <kbd>Format Source Code</kbd> command in Xcode's <kbd>Editor</kbd> menu:

![](screenshot-format.png)

Due to macOS Sandboxing restrictions, this Plugin behaves slightly differently compared to the command line `clang-format` command: It always uses the style selected in the configuration app, and will not use the nearest `.clang-format` file on disk.


### Installing

Download the precompiled app or [build it yourself](#building), then open the app. You might have to right click on the app bundle, and choose <kbd>Open</kbd> to run non-codesigned applications. Then,

* On OS X 10.11, you'll need to run `sudo /usr/libexec/xpccachectl`, then **reboot** to enable app extensions.
* On macOS Sierra, extensions should be loaded by default.


### Keyboard shortcut

To define a keyboard shortcut, open *System Preferences*, click on *Keyboard*, and switch to the *Shortcuts* tab. In the list on the left, select *App Shortcuts*, then hit the <kbd>+</kbd> button. Select Xcode, enter `Format Source Code`, and define a shortcut of your liking.

![](screenshot-shortcut.png)


### Building

To build XcodeClangFormat, run `./configure` on the command line, then build the XcodeClangFormat scheme in the included Xcode project.
