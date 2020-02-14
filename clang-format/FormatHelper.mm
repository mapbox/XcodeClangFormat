#include "FormatHelper.h"
#import <AppKit/AppKit.h>

void updateOffsets(std::vector<size_t>& offsets, NSMutableArray<NSString*>* lines)
{
    offsets.clear();
    offsets.reserve(lines.count + 1);
    offsets.push_back(0);
    size_t offset = 0;
    for (NSString* line in lines)
    {
        offsets.push_back(offset += line.length);
    }
}
