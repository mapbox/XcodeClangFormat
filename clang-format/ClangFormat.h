#import <XcodeKit/XcodeKit.h>

@interface ClangFormat : NSObject

@property NSUserDefaults* defaults;

- (NSData*)getCustomStyle;

@end
