//
//  NSString+RangeHelpers.h
//  Highlightr
//
//  Created by Bruno Philipe on 11/7/18.
//  Copyright © 2018 Bruno Philipe. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (RangeHelpers)

/// Given a range, returns a range that is guaranteed to be a valid range for the receiver string.
- (NSRange)boundedRangeFrom:(NSRange)range;

/// Given a location and a number of characters `count`, returns a range that contains `count` composed characters from
/// the receiver string, starting at `location`.
///
/// If `location` falls inside of a composed character range, this method will shift it backwards to the start of that
/// composed characater.
///
/// Note: This method is meant as a UTF-8 safe replacement for NSMakeRange() when that function is used to create fixed
/// length ranges.
///
/// If a negative value is provided for `count`, the range will be built "backwards", with `location` as upper bound.
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)location count:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
