#import "ClangFormatCommand.h"

#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include "ClangFormat.h"

// Generates a list of offsets for ever line in the array.
void updateOffsets(std::vector<size_t>& offsets, NSMutableArray<NSString*>* lines) {
    offsets.clear();
    offsets.reserve(lines.count + 2);
    offsets.push_back(0);
    size_t offset = 0;
    for (NSString* line in lines) {
        offsets.push_back(offset += [line lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    }
    offsets.push_back(offset);
}

clang::format::FormatStyle::LanguageKind getLanguageKind(XCSourceTextBuffer* buffer) {
    NSString *uti = buffer.contentUTI;
    if ([UTTypeCHeader.identifier isEqualToString:uti]) {
        // C header files could also be Objective-C. We attempt to detect typical Objective-C keywords.
        for (NSString* line in buffer.lines) {
            if ([line hasPrefix:@"#import"] || [line hasPrefix:@"@interface"] || [line hasPrefix:@"@protocol"] ||
                [line hasPrefix:@"@property"] || [line hasPrefix:@"@end"]) {
                return clang::format::FormatStyle::LK_ObjC;
            }
        }
    }
    if ([UTTypeCPlusPlusHeader.identifier isEqualToString:uti] ||
        [UTTypeCPlusPlusSource.identifier isEqualToString:uti] ||
        [UTTypeCHeader.identifier isEqualToString:uti] ||
        [UTTypeCSource.identifier isEqualToString:uti]) {
        return clang::format::FormatStyle::LK_Cpp;
    } else if ([UTTypeObjectiveCSource.identifier isEqualToString:uti] ||
               [UTTypeObjectiveCPlusPlusSource.identifier isEqualToString:uti]) {
        return clang::format::FormatStyle::LK_ObjC;
    } else if ([UTTypeJavaScript.identifier isEqualToString:uti]) {
        return clang::format::FormatStyle::LK_JavaScript;
    }

    return clang::format::FormatStyle::LK_None;
}

NSErrorDomain errorDomain = @"ClangFormatError";

@implementation ClangFormatCommand

NSUserDefaults* defaults = nil;
NSString* kFormatSelectionCommandIdentifier = [NSString stringWithFormat:@"%@.FormatSelection", [[NSBundle mainBundle] bundleIdentifier]];
NSString* kFormatFileCommandIdentifier = [NSString stringWithFormat:@"%@.FormatFile", [[NSBundle mainBundle] bundleIdentifier]];

- (NSData*)getCustomStyle {
    // First, read the regular bookmark because it could've been changed by the wrapper app.
    NSData* regularBookmark = [defaults dataForKey:@"regularBookmark"];
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
    NSData* securityBookmark = [defaults dataForKey:@"securityBookmark"];
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
        [defaults setObject:securityBookmark forKey:@"securityBookmark"];
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

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation*)invocation
                   completionHandler:(void (^)(NSError* _Nullable nilOrError))completionHandler {
    if (!defaults) {
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"XcodeClangFormat"];
    }

    const auto language = getLanguageKind(invocation.buffer);

    NSString* style = [defaults stringForKey:@"style"];
    if (!style) {
        style = @"llvm";
    }

    clang::format::FormatStyle format = clang::format::getNoStyle();
    if ([style isEqualToString:@"custom"]) {
        NSData* config = [self getCustomStyle];
        if (!config) {
            completionHandler([NSError
                errorWithDomain:errorDomain
                           code:0
                       userInfo:@{
                           NSLocalizedDescriptionKey :
                               @"Could not load custom style. Please open XcodeClangFormat.app"
                       }]);
        } else {
            // parse style
            llvm::StringRef configString(reinterpret_cast<const char*>(config.bytes),
                                         config.length);
            clang::format::getPredefinedStyle("LLVM", language, &format);
            auto error = clang::format::parseConfiguration(configString, &format);
            if (error) {
                completionHandler([NSError
                    errorWithDomain:errorDomain
                               code:0
                           userInfo:@{
                               NSLocalizedDescriptionKey :
                                   [NSString stringWithFormat:@"Could not parse custom style: %s.",
                                                              error.message().c_str()]
                           }]);
                return;
            }
        }
    } else {
        auto success = clang::format::getPredefinedStyle(
            llvm::StringRef([style cStringUsingEncoding:NSUTF8StringEncoding]), language, &format);
        if (!success) {
            completionHandler([NSError
                errorWithDomain:errorDomain
                           code:0
                       userInfo:@{
                           NSLocalizedDescriptionKey : [NSString
                               stringWithFormat:@"Could not parse default style %@", style]
                       }]);
            return;
        }
    }

    NSData* buffer = [invocation.buffer.completeBuffer dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray<NSString*>* lines = invocation.buffer.lines;
    llvm::StringRef code(reinterpret_cast<const char*>(buffer.bytes), buffer.length);

    std::vector<size_t> offsets;
    updateOffsets(offsets, lines);

    std::vector<clang::tooling::Range> ranges;

    if ([invocation.commandIdentifier isEqualToString:kFormatSelectionCommandIdentifier]) {
        for (XCSourceTextRange* range in invocation.buffer.selections) {
            const size_t start = offsets[range.start.line] + range.start.column;
            const size_t end = offsets[range.end.line] + range.end.column;
            ranges.emplace_back(start, end - start);
        }
    } else if ([invocation.commandIdentifier isEqualToString:kFormatFileCommandIdentifier]) {
        ranges.emplace_back(0, code.size());
    } else {
        completionHandler([NSError
                           errorWithDomain:errorDomain
                           code:0
                           userInfo:@{
                               NSLocalizedDescriptionKey : @"Unknown command"
                           }]);
        return;
    }

    // Calculated replacements and apply them to the input buffer.
    const llvm::StringRef filename("<stdin>");
    clang::format::FormattingAttemptStatus status;
    auto replaces = clang::format::reformat(*format.GetLanguageStyle(language), code, ranges, filename, &status);

    if (!status.FormatComplete) {
        // We could not apply the calculated replacements.
        completionHandler([NSError
            errorWithDomain:errorDomain
                       code:0
                   userInfo:@{
                       NSLocalizedDescriptionKey : [NSString
                           stringWithFormat:
                               @"Could not complete formatting due to a syntax error on line %u",
                               status.Line]
                   }]);
        return;
    }

    for (auto it = replaces.rbegin(), rend = replaces.rend(); it != rend; ++it) {
        const size_t start = it->getOffset();
        const size_t end = start + it->getLength();
        const auto replacement = it->getReplacementText();

        // In offsets, find the value that is smaller than start.
        auto start_it = std::lower_bound(offsets.begin(), offsets.end(), start);
        auto end_it = std::lower_bound(offsets.begin(), offsets.end(), end);
        if (start_it == offsets.end() || end_it == offsets.end()) {
            continue;
        }

        // We're adding a final offset index that is the position beyond the last byte.
        assert(end_it + 1 != offsets.end());

        // We need to go one line back unless we're at the beginning of the line.
        if (*start_it > start) {
            --start_it;
        }
        if (*end_it > end) {
            --end_it;
        }

        const size_t start_line = std::distance(offsets.begin(), start_it);
        const int64_t start_column = int64_t(start) - int64_t(*start_it);
        assert(start_column >= 0);

        const size_t end_line = std::distance(offsets.begin(), end_it);
        const int64_t end_column = int64_t(end) - int64_t(*end_it);
        assert(end_column >= 0);
        NSData* before_line = [[lines objectAtIndex:start_line] dataUsingEncoding:NSUTF8StringEncoding];
        NSData* after_line = [[lines objectAtIndex:end_line] dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableData* replacement_data = [[NSMutableData alloc] initWithBytes:before_line.bytes length:start_column];
        [replacement_data appendBytes:replacement.data() length:replacement.size()];
        [replacement_data appendBytes:(reinterpret_cast<const char*>(after_line.bytes) + end_column) length: (after_line.length - end_column)];

        NSString* string = [[NSString alloc] initWithData:replacement_data encoding:NSUTF8StringEncoding];
        NSMutableArray* replacements = [[NSMutableArray alloc] init];
        [string
            enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByLines
                            usingBlock:^(NSString* _Nullable,
                                         NSRange,
                                         NSRange enclosingRange,
                                         BOOL* _Nonnull) {
                              [replacements addObject:[string substringWithRange:enclosingRange]];
                            }];

        NSRange range =
            NSMakeRange(start_line, end_line - start_line + (end_line < lines.count ? 1 : 0));
        [lines replaceObjectsInRange:range withObjectsFromArray:replacements];
    }

    completionHandler(nil);
}

@end
