#ifndef FormatHelper_h
#define FormatHelper_h

#import <XcodeKit/XcodeKit.h>
#include <clang/Format/Format.h>

void updateOffsets(std::vector<size_t>& offsets, NSMutableArray<NSString*>* lines);

#endif /* FormatHelper_h */
