//
//  NSString+RangeHelpers.m
//  Highlightr
//
//  Created by Bruno Philipe on 11/7/18.
//  Copyright © 2018 Bruno Philipe. All rights reserved.
//

#import "NSString+RangeHelpers.h"

@implementation NSString (RangeHelpers)

- (NSRange)boundedRangeFrom:(NSRange)range
{
	NSInteger newLocation = MAX(0, range.location);
	return NSMakeRange(newLocation, MIN([self length], NSMaxRange(range)) - newLocation);
}

- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)location count:(NSInteger)count
{
	if ([self length] == location || (location == 0 && count < 0))
	{
		return NSMakeRange(location, 0);
	}

	NSUInteger startIndex = [self rangeOfComposedCharacterSequenceAtIndex:location].location;

	if (startIndex == NSNotFound)
	{
		// Dunno what could possibly cause this, but let's be safe.
		return NSMakeRange(NSNotFound, 0);
	}

	if (count == 0)
	{
		return NSMakeRange(startIndex, 0);
	}

	__block NSUInteger totalLength = 0;
	__block NSInteger composedCharsCount = 0;

	if (count > 0)
	{
		[self enumerateSubstringsInRange:NSMakeRange(startIndex, [self length] - startIndex)
								 options:NSStringEnumerationByComposedCharacterSequences
							  usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop)
		 {
			 totalLength += substringRange.length;
			 composedCharsCount += 1;

			 if (composedCharsCount >= count)
			 {
				 *stop = YES;
			 }
		 }];

		return NSMakeRange(startIndex, totalLength);
	}
	else
	{
		[self enumerateSubstringsInRange:NSMakeRange(startIndex, [self length] - startIndex)
								 options:NSStringEnumerationByComposedCharacterSequences|NSStringEnumerationReverse
							  usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop)
		 {
			 totalLength += substringRange.length;
			 composedCharsCount -= 1;

			 if (composedCharsCount <= count)
			 {
				 *stop = YES;
			 }
		 }];

		return NSMakeRange(startIndex - totalLength, totalLength);
	}
}

@end
