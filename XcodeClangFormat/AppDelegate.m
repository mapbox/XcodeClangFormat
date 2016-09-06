#import "AppDelegate.h"

@interface AppDelegate ()

@property(weak) IBOutlet NSWindow *window;
@property(weak) IBOutlet NSButton *llvmStyle;
@property(weak) IBOutlet NSButton *googleStyle;
@property(weak) IBOutlet NSButton *chromiumStyle;
@property(weak) IBOutlet NSButton *mozillaStyle;
@property(weak) IBOutlet NSButton *webkitStyle;
@property(weak) IBOutlet NSButton *customStyle;
@property(weak) IBOutlet NSPathControl *primaryPathControl;
@property(weak) IBOutlet NSPathControl *secondaryPathControl;
@end

@implementation AppDelegate

NSUserDefaults* defaults = nil;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    defaults = [[NSUserDefaults alloc] initWithSuiteName: @"XcodeClangFormat"];

    NSString* style = [defaults stringForKey:@"style"];
    if (!style) {
        style = @"llvm";
    }

    if ([style isEqualToString: @"custom"]) {
        self.customStyle.state = NSOnState;
    } else if ([style isEqualToString: @"google"]) {
        self.googleStyle.state = NSOnState;
    } else if ([style isEqualToString: @"chromium"]) {
        self.chromiumStyle.state = NSOnState;
    } else if ([style isEqualToString: @"mozilla"]) {
        self.mozillaStyle.state = NSOnState;
    } else if ([style isEqualToString: @"webkit"]) {
        self.webkitStyle.state = NSOnState;
    } else {
        self.llvmStyle.state = NSOnState;
    }

    NSData* bookmark = [defaults dataForKey:@"file"];
    if (bookmark) {
        NSError *error = nil;
        BOOL stale = NO;
        NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                               options:NSURLBookmarkResolutionWithSecurityScope | NSURLBookmarkResolutionWithoutUI
                                         relativeToURL:nil
                                   bookmarkDataIsStale:&stale
                                                 error:&error];

        if (url) {
            // Regenerate the bookmark, so that the extension can read a valid bookmark after a
            // system restart.
            [url startAccessingSecurityScopedResource];
            NSData* regularBookmark = [url bookmarkDataWithOptions:0
                                includingResourceValuesForKeys:nil
                                                 relativeToURL:nil
                                                         error:nil];
            [url stopAccessingSecurityScopedResource];
            [defaults setObject:regularBookmark forKey:@"regularBookmark"];

            self.primaryPathControl.URL = url;
            self.secondaryPathControl.URL = url;
        } else {
            // Remove the bookmark value from the storage
            [defaults setNilValueForKey:@"regularBookmark"];
        }
        [defaults synchronize];
    }
}

- (BOOL)application:(NSApplication *)application
           openFile:(NSString *)filename {
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", filename]];
    return [self selectURL:url];
}

- (IBAction)chooseStyle:(id)sender {
    NSString* style = nil;
    if (sender == self.customStyle) {
        style = @"custom";
    } else if (sender == self.googleStyle) {
        style = @"google";
    } else if (sender == self.chromiumStyle) {
        style = @"chromium";
    } else if (sender == self.mozillaStyle) {
        style = @"mozilla";
    } else if (sender == self.webkitStyle) {
        style = @"webkit";
    } else {
        style = @"llvm";
    }

    [defaults setValue:style forKey:@"style"];
    [defaults synchronize];
}

- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel {
    openPanel.title = @"Choose custom .clang-format file";
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = YES;
    openPanel.showsHiddenFiles = YES;
    openPanel.treatsFilePackagesAsDirectories = YES;
    openPanel.allowsMultipleSelection = NO;
}

- (NSURL *)findClangFormatFileFromURL:(NSURL *)url {
    NSNumber *isDirectory;
    BOOL success = [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    if (success && [isDirectory boolValue]) {
        return [url URLByAppendingPathComponent:@".clang-format"];
    } else {
        return url;
    }
}

- (NSData *)tryCreateBookmarkFromURL:(NSURL *)url {
    // Create a bookmark and store into defaults.
    NSError *error = nil;
    return [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
         includingResourceValuesForKeys:nil
                          relativeToURL:nil
                                  error:&error];

}

- (NSDragOperation)pathControl:(NSPathControl *)pathControl validateDrop:(id<NSDraggingInfo>)info {
    NSPasteboard *pastboard = [info draggingPasteboard];
    NSURL *url = [self findClangFormatFileFromURL: [NSURL URLFromPasteboard:pastboard]];
    NSData *bookmark = [self tryCreateBookmarkFromURL:url];
    if (bookmark) {
        return NSDragOperationCopy;
    } else {
        return NSDragOperationNone;
    }
}

- (IBAction)selectFile:(id)sender {
    NSURL* url =  [self findClangFormatFileFromURL: self.primaryPathControl.URL];
    [self selectURL:url];
}

- (BOOL)selectURL:(NSURL *)url {
    NSData *bookmark = [self tryCreateBookmarkFromURL:url];

    if (bookmark == nil) {
        return NO;
    } else {
        self.primaryPathControl.URL = url;
        self.secondaryPathControl.URL = url;
        self.customStyle.state = NSOnState;

        [defaults setValue:@"custom" forKey:@"style"];
        [defaults setObject:bookmark forKey:@"file"];

        NSData* regularBookmark = [url bookmarkDataWithOptions:0
                                includingResourceValuesForKeys:nil
                                                 relativeToURL:nil
                                                         error:nil];
        [defaults setObject:regularBookmark forKey:@"regularBookmark"];
        [defaults synchronize];
        return YES;
    }
}

@end

