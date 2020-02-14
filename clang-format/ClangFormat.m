#import "ClangFormat.h"

@implementation ClangFormat

- (NSData*)getCustomStyle {
    // First, read the regular bookmark because it could've been changed by the wrapper app.
    NSData* regularBookmark = [_defaults dataForKey:@"regularBookmark"];
    NSURL* regularURL = nil;
    BOOL regularStale = NO;
    if (regularBookmark) {
        regularURL = [NSURL URLByResolvingBookmarkData:regularBookmark
                                               options:NSURLBookmarkResolutionWithoutUI
                                         relativeToURL:nil
                                   bookmarkDataIsStale:&regularStale
                                                 error:nil];
    }

    if (!regularURL) {
        return nil;
    }

    // Then read the security URL, which is the URL we're actually going to use to access the file.
    NSData* securityBookmark = [_defaults dataForKey:@"securityBookmark"];
    NSURL* securityURL = nil;
    BOOL securityStale = NO;
    if (securityBookmark) {
        securityURL = [NSURL URLByResolvingBookmarkData:securityBookmark
                                                options:NSURLBookmarkResolutionWithSecurityScope |
                                                        NSURLBookmarkResolutionWithoutUI
                                          relativeToURL:nil
                                    bookmarkDataIsStale:&securityStale
                                                  error:nil];
    }

    // Clear out the security URL if it's no longer matching the regular URL.
    if (securityStale == YES ||
        (securityURL && ![[securityURL path] isEqualToString:[regularURL path]])) {
        securityURL = nil;
    }

    if (!securityURL && regularStale == NO) {
        // Attempt to create new security URL from the regular URL to persist across system reboots.
        NSError* error = nil;
        securityBookmark = [regularURL
                   bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope |
                                           NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
            includingResourceValuesForKeys:nil
                             relativeToURL:nil
                                     error:&error];
        [_defaults setObject:securityBookmark forKey:@"securityBookmark"];
        securityURL = regularURL;
    }

    if (securityURL) {
        // Finally, attempt to read the .clang-format file
        NSError* error = nil;
        [securityURL startAccessingSecurityScopedResource];
        NSData* data = [NSData dataWithContentsOfURL:securityURL options:0 error:&error];
        [securityURL stopAccessingSecurityScopedResource];
        if (error) {
            NSLog(@"Error loading from security bookmark: %@", error);
        } else if (data) {
            return data;
        }
    }

    return nil;
}


@end
