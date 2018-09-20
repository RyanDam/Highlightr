//
//  HighlightHints.h
//  Highlightr
//
//  Created by Bruno Philipe on 4/3/18.
//

#import <Foundation/Foundation.h>

@interface HighlightHints : NSObject

/**
 Helper method to look for highlight boundaries in source code. Uses `lowerHighlightBoundaryForRange` and
 `upperHighlightBoundaryForRange` to search for boundaries, and depending on their results produces a valid range.
 In case all fails, returns the paragraph range of the given range.

 @param range The original highlight range. Will search before and after this range.
 @param string The content to search. `range` should be fully contained in this string.
 @param language The name of the source languge. For example, "css".
 @return A valid highlight range containing at least the paragraph range of `range`.
 */
+ (NSRange)highlightRangeFor:(NSRange)range inString:(nonnull NSString *)string forLanguage:(nullable NSString *)language;

@end
