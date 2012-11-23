//
//  CommentInfo.m
//  appledoc
//
//  Created by Tomaz Kragelj on 6/16/12.
//  Copyright (c) 2012 Tomaz Kragelj. All rights reserved.
//

#import "Objects.h"
#import "CommentInfo.h"

@implementation CommentInfo

#pragma mark - Properties

- (NSMutableArray *)commentParameters {
	if (_commentParameters) return _commentParameters;
	LogDebug(@"Initializing comment parameters array due to first access...");
	_commentParameters = [[NSMutableArray alloc] init];
	return _commentParameters;
}

- (NSMutableArray *)commentExceptions {
	if (_commentExceptions) return _commentExceptions;
	LogDebug(@"Initializing comment exceptions array due to first access...");
	_commentExceptions = [[NSMutableArray alloc] init];
	return _commentExceptions;
}

#pragma mark - Helper methods

- (BOOL)isCommentAbstractRegistered {
	return (self.commentAbstract != nil);
}

@end

#pragma mark - 

@implementation CommentInfo (Logging)

- (NSString *)description {
	return [self.sourceString gb_description];
}

- (NSString *)debugDescription {
	return self.sourceString;
}

@end