//
//  NSTextStorage+Helpers.m
//  Highlightr
//
//  Created by Bruno Philipe on 23.01.20.
//

#import "NSTextStorage+Helpers.h"
#import "NSString+RangeHelpers.h"

const _Nonnull NSAttributedStringKey HighlightLanguageBlock = @"LanguageBlock";
const _Nonnull NSAttributedStringKey HighlightCommentBlock = @"CommentBlock";
const _Nonnull NSAttributedStringKey HighlightMultiLineElementBlock = @"MultiLineElementBlock";

@implementation NSTextStorage (Helpers)

/// Looks for the closest language hints both behind and ahead of the parameter range, ensuring that highlighting
/// will generate a meaningful result.
- (NSRange)languageBoundariesForRange:(NSRange)range
							 language:(NSString *)language
					effectiveLanguage:(NSString **)effectiveLangauge
{
	NSUInteger storageLength = [self length];
	NSInteger __block startLocation = NSNotFound;
	NSInteger __block endLocation = storageLength;
	NSString __block *highlightLanguage = language;

	if (!highlightLanguage)
	{
		highlightLanguage = @"";
	}

	// Search for the nearest language boundary before the edited range.
	[self enumerateAttribute:HighlightLanguageBlock
					 inRange:NSMakeRange(0, MIN(range.location, endLocation))
					 options:NSAttributedStringEnumerationReverse
				  usingBlock:^(id _Nullable value, NSRange effectiveRange, BOOL * _Nonnull stop)
	 {
		 if ([value isKindOfClass:[NSString class]])
		 {
			 highlightLanguage = value;
			 startLocation = effectiveRange.location;
			 *stop = YES;
		 }
	 }];

	// Search for the nearest language boundary after the edited range.
	NSUInteger positionAhead = NSMaxRange(range);

	// If this is false, then we are editing the last char of the text storage.
	if (positionAhead < storageLength)
	{
		[self enumerateAttribute:HighlightLanguageBlock
						 inRange:NSMakeRange(positionAhead, storageLength - positionAhead)
						 options:0
					  usingBlock:^(id _Nullable value, NSRange effectiveRange, BOOL * _Nonnull stop)
		 {
			 if ([value isKindOfClass:[NSString class]] && ![value isEqualToString:highlightLanguage])
			 {
				 endLocation = effectiveRange.location;
				 *stop = YES;
			 }
		 }];
	}

	if (startLocation == NSNotFound)
	{
		return NSMakeRange(NSNotFound, 0);
	}

	*effectiveLangauge = highlightLanguage;

	return NSMakeRange(startLocation, endLocation - startLocation);
}

- (BOOL)isRangeInCommentBoundary:(NSRange)range
{
	NSRange lineRange = [[self string] lineRangeForRange:range];
	NSUInteger lowerIndex = [[self string] rangeOfComposedCharacterSequenceAtIndex:lineRange.location count:-1].location;
	NSUInteger upperIndex = [[self string] rangeOfComposedCharacterSequenceAtIndex:NSMaxRange(lineRange) count:1].location;

	if (lineRange.location == lowerIndex && lowerIndex > 0)
	{
		// The line range won't do in this case, we will need to look up on the previous line.
		lowerIndex = [[self string] rangeOfComposedCharacterSequenceAtIndex:lowerIndex count:-1].location;
	}

	if (upperIndex == NSMaxRange(lineRange) && upperIndex < [self length])
	{
		// The max line range won't do, we will have to lookup on the next line.
		upperIndex = [[self string] rangeOfComposedCharacterSequenceAtIndex:upperIndex count:1].location;
	}

	id lowerAttribute = lowerIndex < [self length] ? [self attribute:HighlightCommentBlock atIndex:lowerIndex effectiveRange:nil] : nil;
	id upperAttribute = upperIndex < [self length] ? [self attribute:HighlightCommentBlock atIndex:upperIndex effectiveRange:nil] : nil;

	return (lowerAttribute == nil && upperAttribute != nil) || (lowerAttribute != nil && upperAttribute == nil);
}

/**
 Search for HighlightMultiLineElementBlock attributes in the receiver attributed string and return the shortest
 immediatelly adjacent range that has this attribute set and encompasses the provided range.

 If no such attributes are found immediatelly adjacent to the provided range, returns that range value.

 @param range The search range.
 @return A contiguous multi-line element range encompassing `range`, or `range` if such attributes are not found.
 */
- (NSRange)contiguousElementRangeFor:(NSRange)range
{
	NSRange effectiveLowerRange = range, effectiveUpperRange = range;
	id lowerValue = nil, upperValue = nil;
	NSUInteger rangeUpperBound = NSMaxRange(range);

	if (range.location < [self length])
	{
		lowerValue = [self attribute:HighlightMultiLineElementBlock
							 atIndex:range.location
					  effectiveRange:&effectiveLowerRange];

		if (lowerValue)
		{
			lowerValue = [self attribute:HighlightMultiLineElementBlock
								 atIndex:range.location
				   longestEffectiveRange:&effectiveLowerRange
								 inRange:NSMakeRange(0, rangeUpperBound)];
		}
	}

	if (rangeUpperBound < [self length])
	{
		upperValue = [self attribute:HighlightMultiLineElementBlock
							 atIndex:rangeUpperBound
					  effectiveRange:&effectiveUpperRange];

		if (upperValue)
		{
			upperValue = [self attribute:HighlightMultiLineElementBlock
								 atIndex:rangeUpperBound
				   longestEffectiveRange:&effectiveUpperRange
								 inRange:NSMakeRange(rangeUpperBound, [self length] - rangeUpperBound)];
		}
	}

	if (lowerValue != nil && upperValue != nil)
	{
		return NSUnionRange(effectiveLowerRange, effectiveUpperRange);
	}
	else if (lowerValue != nil)
	{
		return NSUnionRange(effectiveLowerRange, range);
	}
	else if (upperValue != nil)
	{
		return NSUnionRange(range, effectiveUpperRange);
	}
	else
	{
		return range;
	}
}

@end
