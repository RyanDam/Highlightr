//
//  HighlightHints.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/3/18.
//

#import "HighlightHints.h"
#import "NSString+RangeHelpers.h"

@implementation HighlightHints

+ (NSUInteger)lowerHighlightBoundaryFor:(NSRange)range inString:(nonnull NSString *)string forLanguage:(nullable NSString *)language
{
	NSRange searchRange = NSMakeRange(0, range.location);

	if ([language isEqualToString:@"css"])
	{
		// Looks for the curly braces, which define the inner blocks of CSS
		NSRange curlyBraceRange = [string rangeOfString:@"{"
												options:NSBackwardsSearch
												  range:searchRange];

		return curlyBraceRange.location;
	}

	return NSNotFound;
}

+ (NSUInteger)upperHighlightBoundaryFor:(NSRange)range inString:(nonnull NSString *)string forLanguage:(nullable NSString *)language
{
	NSRange searchRange = NSMakeRange(NSMaxRange(range), [string length] - NSMaxRange(range));

	if ([language isEqualToString:@"css"])
	{
		// Looks for the curly braces, which define the inner blocks of CSS
		NSRange curlyBraceRange = [string rangeOfString:@"}"
												options:0
												  range:searchRange];

		return curlyBraceRange.location;
	}

	return NSNotFound;
}

+ (NSRange)highlightRangeFor:(NSRange)range inString:(nonnull NSString *)string forLanguage:(nullable NSString *)language
{
	range = [string boundedRangeFrom:range];

	if (language == nil)
	{
		// Fallback
		return [string paragraphRangeForRange:range];
	}

	NSUInteger lowerBound = [self lowerHighlightBoundaryFor:range inString:string forLanguage:language];
	NSUInteger upperBound = [self upperHighlightBoundaryFor:range inString:string forLanguage:language];

	if (lowerBound != NSNotFound && upperBound != NSNotFound)
	{
		return NSUnionRange([string rangeOfComposedCharacterSequenceAtIndex:lowerBound count:1],
							[string rangeOfComposedCharacterSequenceAtIndex:upperBound count:1]);
	}
	else if (lowerBound != NSNotFound)
	{
		return NSUnionRange([string rangeOfComposedCharacterSequenceAtIndex:lowerBound count:1], range);
	}
	else if (upperBound != NSNotFound)
	{
		return NSUnionRange(range, [string rangeOfComposedCharacterSequenceAtIndex:upperBound count:1]);
	}
	else
	{
		// Fallback
		return [string paragraphRangeForRange:range];
	}
}

@end
