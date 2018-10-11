//
//  HighlightHints.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/3/18.
//

#import "HighlightHints.h"
#import "NSString+RangeHelpers.h"

@implementation HighlightHints

+ (nonnull NSSet<NSString *> *)blockCommentLanguages
{
	static NSSet<NSString *> *languagesSet = nil;

	if (languagesSet == nil)
	{
		languagesSet = [[NSSet<NSString *> alloc] initWithObjects:@"actionscript", @"arduino", @"armasm", @"aspectj",
						@"autohotkey", @"avrasm", @"axapta", @"bnf", @"cal", @"clean", @"cos", @"cpp", @"cs", @"css",
						@"d", @"dart", @"delphi", @"dts", @"ebnf", @"flix", @"gams", @"gauss", @"gcode", @"glsl", @"go",
						@"gradle", @"groovy", @"haxe", @"hsp", @"java", @"javascript", @"kotlin", @"lasso", @"less",
						@"livecodeserver", @"mathematica", @"mel", @"mercury", @"mipsasm", @"n1ql", @"nix", @"nsis",
						@"objectivec", @"openscad", @"php", @"pony", @"processing", @"prolog", @"qml", @"rsl",
						@"ruleslanguage", @"scala", @"scss", @"sqf", @"sql", @"stan", @"stata", @"step21", @"stylus",
						@"swift", @"thrift", @"typescript", @"vala", @"verilog", @"vhdl", @"xl", @"zephir", nil];
	}

	return languagesSet;
}

+ (NSRange)highlightRangeFor:(NSRange)range
					inString:(nonnull NSString *)string
				 forLanguage:(nullable NSString *)language
	isInCommentBlockBoundary:(BOOL)isCommentBlockBoundary
{
	range = [string boundedRangeFrom:range];

	if (language == nil)
	{
		// Fallback
		return [string paragraphRangeForRange:range];
	}

	NSUInteger lowerBoundary = NSNotFound;
	NSUInteger upperBoundary = NSNotFound;

	NSRange lowerSearchRange = NSMakeRange(0, range.location);
	NSRange upperSearchRange = NSMakeRange(NSMaxRange(range), [string length] - NSMaxRange(range));

	BOOL lowerBoundayIsCommentBlock = NO;

	if ([language isEqualToString:@"css"])
	{
		// Looks for the curly braces, which define the inner blocks of CSS
		lowerBoundary = [string rangeOfString:@"{" options:NSBackwardsSearch range:lowerSearchRange].location;
	}
	else if ([[self blockCommentLanguages] containsObject:language])
	{
		if (NSMaxRange(lowerSearchRange) < [string length])
		{
			lowerSearchRange.length += 1;
		}

		NSRange lineRange = [string lineRangeForRange:lowerSearchRange];
		
		// This is the range that will be highlighted if all hinting fails. We should be aware of it.
		NSRange fallbackHighlightRange = [string lineRangeForRange:range];

		NSUInteger openLocation = [string rangeOfString:@"(^|[^/])/\\*"
												options:NSBackwardsSearch|NSRegularExpressionSearch
												  range:lineRange].location;

		NSUInteger closeLocation = NSMaxRange([string rangeOfString:@"*/" options:NSBackwardsSearch range:lineRange]);

		if (openLocation != NSNotFound //  we found open location
			&& (closeLocation == NSNotFound // and no close location
				|| openLocation > closeLocation // or close is before open
				|| NSLocationInRange(closeLocation - 1, fallbackHighlightRange))) // or close is in fallback highlight range
		{
			// We are inside a comment block so we must include the open tag it in the highlight.
			lowerBoundary = openLocation;
			lowerBoundayIsCommentBlock = YES;
		}
		else if (isCommentBlockBoundary)
		{
			// It is likely the user has deleted a comment block started statement. We might need to highlight
			// everything down from here.
			lowerBoundary = [string lineRangeForRange:range].location;
		}
	}

	if ([language isEqualToString:@"css"])
	{
		// Looks for the curly braces, which define the inner blocks of CSS
		upperBoundary = [string rangeOfString:@"}" options:0 range:upperSearchRange].location;
	}
	else if ([[self blockCommentLanguages] containsObject:language])
	{
		NSUInteger openLocation = [string rangeOfString:@"/*" options:0 range:upperSearchRange].location;
		NSUInteger closeLocation = NSMaxRange([string rangeOfString:@"*/" options:0 range:upperSearchRange]);

		if (openLocation != NSNotFound && closeLocation != NSNotFound && openLocation > closeLocation)
		{
			// We found out that we are inside a comment block so we must include the close tag it in the highlight.
			upperBoundary = closeLocation;
		}
		else if ((lowerBoundayIsCommentBlock || isCommentBlockBoundary) && closeLocation == NSNotFound)
		{
			upperBoundary = [string length];
		}
	}

	if (lowerBoundary != NSNotFound && upperBoundary != NSNotFound)
	{
		return NSMakeRange(lowerBoundary, upperBoundary - lowerBoundary);
	}
	else if (lowerBoundary != NSNotFound)
	{
		return NSMakeRange(lowerBoundary, NSMaxRange(range) - lowerBoundary);
	}
	else if (upperBoundary != NSNotFound)
	{
		return NSMakeRange(range.location, upperBoundary - range.location);
	}
	else
	{
		return NSMakeRange(NSNotFound, 0);
	}
}

@end
