#import "ClangFormatFileCommand.h"

#import <AppKit/AppKit.h>
#include <clang/Format/Format.h>
#include "FormatHelper.h"

NSErrorDomain clangFileFormatErrorDomain = @"ClangFileFormatError";

@implementation ClangFormatFileCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation*)invocation
                   completionHandler:(void (^)(NSError* _Nullable nilOrError))completionHandler
{
    if (!self.defaults)
    {
        self.defaults = [[NSUserDefaults alloc] initWithSuiteName:@"XcodeClangFormat"];
    }

    NSString* style = [self.defaults stringForKey:@"style"];
    if (!style)
    {
        style = @"llvm";
    }

    clang::format::FormatStyle format = clang::format::getLLVMStyle();
    format.Language = clang::format::FormatStyle::LK_Cpp;
    clang::format::getPredefinedStyle("LLVM", format.Language, &format);
    if ([style isEqualToString:@"custom"])
    {
        NSData* config = [self getCustomStyle];
        if (!config)
        {
            completionHandler([NSError
                errorWithDomain:clangFileFormatErrorDomain
                           code:0
                       userInfo:@{ NSLocalizedDescriptionKey : @"Could not load custom style. Please open XcodeClangFormat.app" }]);
        }
        else
        {
            // parse style
            llvm::StringRef configString(reinterpret_cast<const char*>(config.bytes), config.length);
            auto error = clang::format::parseConfiguration(configString, &format);
            if (error)
            {
                completionHandler([NSError errorWithDomain:clangFileFormatErrorDomain
                                                      code:0
                                                  userInfo:@{
                                                      NSLocalizedDescriptionKey : [NSString
                                                          stringWithFormat:@"Could not parse custom style: %s.", error.message().c_str()]
                                                  }]);
                return;
            }
        }
    }
    else
    {
        auto success = clang::format::getPredefinedStyle(llvm::StringRef([style cStringUsingEncoding:NSUTF8StringEncoding]),
                                                         clang::format::FormatStyle::LanguageKind::LK_Cpp,
                                                         &format);
        if (!success)
        {
            completionHandler([NSError
                errorWithDomain:clangFileFormatErrorDomain
                           code:0
                       userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Could not parse default style %@", style] }]);
            return;
        }
    }
    NSData* buffer = [invocation.buffer.completeBuffer dataUsingEncoding:NSUTF8StringEncoding];
    llvm::StringRef code(reinterpret_cast<const char*>(buffer.bytes), buffer.length);

    std::vector<size_t> offsets;
    updateOffsets(offsets, invocation.buffer.lines);

    std::vector<clang::tooling::Range> ranges;
    size_t start = 0;
    for (NSString* range in invocation.buffer.lines)
    {
        ranges.emplace_back(start, [range length]);
        start += [range length];
    }

    // Calculated replacements and apply them to the input buffer.
    const llvm::StringRef filename("<stdin>");
    clang::format::FormattingAttemptStatus status;
    auto replaces = clang::format::reformat(format, code, ranges, filename, &status);
    auto result = clang::tooling::applyAllReplacements(code, replaces);
            
    if (!status.FormatComplete)
    {
        // We could not apply the calculated replacements.
        completionHandler([NSError errorWithDomain:clangFileFormatErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey : @"Failed to apply formatting replacements." }]);
        return;
    }
    
    auto includeReplaces = clang::format::sortIncludes(format, result->data(), ranges, filename);
    auto includeReplaceResult = clang::tooling::applyAllReplacements(result->data(), includeReplaces);
    if (!includeReplaceResult)
    {
       // We could not apply the calculated replacements.
       completionHandler([NSError errorWithDomain:clangFileFormatErrorDomain
                                             code:0
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Failed to apply formatting replacements to includes." }]);
       return;
    }
    
    // Remove all selections before replacing the completeBuffer, otherwise we get crashes when
    // changing the buffer contents because it tries to automatically update the selections, which
    // might be out of range now.
    [invocation.buffer.selections removeAllObjects];

    // Update the entire text with the result we got after applying the replacements.
    invocation.buffer.completeBuffer = [[NSString alloc] initWithBytes:includeReplaceResult->data() length:includeReplaceResult->size() encoding:NSUTF8StringEncoding];

    completionHandler(nil);
}

@end
