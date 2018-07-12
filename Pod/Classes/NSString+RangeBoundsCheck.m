//
//  NSString+RangeBoundsCheck.m
//  Highlightr
//
//  Created by Bruno Philipe on 11/7/18.
//  Copyright © 2018 Bruno Philipe. All rights reserved.
//

#import "NSString+RangeBoundsCheck.h"

@implementation NSString (RangeBoundsCheck)

- (NSRange)boundedRangeFrom:(NSRange)range
{
	NSInteger newLocation = MAX(0, range.location);
	return NSMakeRange(newLocation, MIN([self length], NSMaxRange(range)) - newLocation);
}

@end
