//
//  ObjectiveCEnumState.m
//  appledoc
//
//  Created by Tomaž Kragelj on 3/20/12.
//  Copyright (c) 2012 Tomaz Kragelj. All rights reserved.
//

#import "StateBase.h"
#import "ObjectiveCEnumState.h"

@interface ObjectiveCEnumItemState : BlockStateBase
- (void)parseToken:(PKToken *)token;
@property (nonatomic, strong) PKToken *startToken;
@property (nonatomic, strong) PKToken *endToken;
@property (nonatomic, strong) ObjectiveCParseData *data;
@end

#pragma mark - 

@interface ObjectiveCEnumState ()
@property (nonatomic, strong) ObjectiveCEnumItemState *enumItemState;
@property (nonatomic, strong) ObjectiveCEnumItemState *enumValueState;
@property (nonatomic, strong) ContextBase *enumItemContext;
@property (nonatomic, strong) NSArray *enumItemDelimiters;
@property (nonatomic, assign) BOOL wasEnumNameParsed;
@end

#pragma mark - 

@implementation ObjectiveCEnumState

#pragma mark - Parsing

- (NSUInteger)parseWithData:(ObjectiveCParseData *)data {
	if (![self consumeEnumStartTokens:data]) return GBResultFailedMatch;
	if (![self parseEnumNameBeforeBody:data]) return GBResultFailedMatch;
	if (![self parseEnumBody:data]) return GBResultFailedMatch;
	if (![self parseEnumBodyEnd:data]) return GBResultFailedMatch;
	if (![self parseEnumNameAfterBody:data]) return GBResultFailedMatch;
	if (![self finalizeEnum:data]) return GBResultFailedMatch;
	return GBResultOk;
}

- (BOOL)consumeEnumStartTokens:(ObjectiveCParseData *)data {
	LogDebug(@"Matched enum.");
	[data.store setCurrentSourceInfo:data.stream.current];
	[data.store beginEnumeration];
	[data.stream consume:1];
	return YES;
}

- (BOOL)parseEnumNameBeforeBody:(ObjectiveCParseData *)data {
	LogDebug(@"Matching enum body start.");
	
	__block PKToken *nameToken = nil;
	NSUInteger result = [data.stream matchUntil:@"{" block:^(PKToken *token, NSUInteger lookahead, BOOL *stop) { 
		if ([token matches:@"{"]) return;
		nameToken = token;
	}];
	if (result == NSNotFound) {
		LogDebug(@"Failed matching enum body start, bailing out.");
		[data.store cancelCurrentObject]; // enum
		[data.parser popState];
		return NO;
	}
	
	if (nameToken) {
		LogDebug(@"Matched enum name %@.", nameToken);
		[data.store appendEnumerationName:nameToken.stringValue];
	}
	self.wasEnumNameParsed = (nameToken != nil);
	return YES;
}

- (BOOL)parseEnumBody:(ObjectiveCParseData *)data {
	LogDebug(@"Matching enum body.");
	self.enumItemContext.currentState = self.enumItemState;
	self.enumItemState.data = data;
	self.enumValueState.data = data;
	NSUInteger result = [data.stream matchUntil:@"}" block:^(PKToken *token, NSUInteger lookahead, BOOL *stop) {
		if ([token matches:self.enumItemDelimiters]) {
			LogDebug(@"Matched '%@', ending item.", token);
			[self.enumItemContext changeStateTo:self.enumItemState];
		} else if ([token matches:@"="]) {
			LogDebug(@"Matched '%@', registering value.", token);
			[self.enumItemContext changeStateTo:self.enumValueState];
		} else {
			LogDebug(@"Matching '%@'.", token);
			[self.enumItemContext.currentState parseToken:token];
		}		
	}];
	if (result == NSNotFound) {
		LogDebug(@"Failed matching end of enum body, bailing out.");
		[data.stream consume:1];
		[data.store cancelCurrentObject]; // enum
		[data.parser popState];
		return NO;
	}
	return YES;
}

- (BOOL)parseEnumBodyEnd:(ObjectiveCParseData *)data {
	LogDebug(@"Matching enum ending semicolon.");
	if (![data.stream.current matches:@";"]) {
		LogDebug(@"Failed matching ending enum semicolon, bailing out.");
		[data.store cancelCurrentObject];
		[data.parser popState];
		return NO;
	}
	[data.stream consume:1];
	return YES;
}

- (BOOL)parseEnumNameAfterBody:(ObjectiveCParseData *)data {
	if (self.wasEnumNameParsed) {
		self.wasEnumNameParsed = NO;
		return YES;
	}
	
	if (![data.stream matches:@"typedef", GBTokens.any, GBTokens.any, @";", nil]) return YES;
	PKToken *nameToken = [data.stream la:2];
	[data.store appendEnumerationName:nameToken.stringValue];
	[data.stream consume:4];
	return YES;
}

- (BOOL)finalizeEnum:(ObjectiveCParseData *)data {
	LogDebug(@"Ending enum.");
	LogVerbose(@"\n%@", data.store.currentRegistrationObject);
	[data.store endCurrentObject]; // enum
	[data.parser popState];
	return YES;
}

#pragma mark - Item state handling

- (ContextBase *)enumItemContext {
	if (_enumItemContext) return _enumItemContext;
	LogDebug(@"Initializing enum item context due to first access...");
	_enumItemContext = [[ContextBase alloc] init];
	return _enumItemContext;
}

- (ObjectiveCEnumItemState *)enumItemState {
	if (_enumItemState) return _enumItemState;
	LogDebug(@"Initializing enum item state due to first access...");
	_enumItemState = [[ObjectiveCEnumItemState alloc] init];
	_enumItemState.willResignCurrentStateBlock = ^(ObjectiveCEnumItemState *state, id context){
		NSString *value = [state.data.stream stringStartingWith:state.startToken endingWith:state.endToken];
		if (value.length == 0) return;
		[state.data.store appendEnumerationItem:value];
	};
	return _enumItemState;
}

- (ObjectiveCEnumItemState *)enumValueState {
	if (_enumValueState) return _enumValueState;
	LogDebug(@"Initializing enum value state due to first access...");
	_enumValueState = [[ObjectiveCEnumItemState alloc] init];
	_enumValueState.willResignCurrentStateBlock = ^(ObjectiveCEnumItemState *state, id context){
		NSString *value = [state.data.stream stringStartingWith:state.startToken endingWith:state.endToken];
		if (value.length == 0) return;
		[state.data.store appendEnumerationValue:value];
	};
	return _enumValueState;
}

#pragma mark - Properties

- (NSArray *)enumItemDelimiters {
	if (_enumItemDelimiters) return _enumItemDelimiters;
	LogDebug(@"Initializing enum item delimiters due to first access...");
	_enumItemDelimiters = @[@",", @"}", @";"];
	return _enumItemDelimiters;
}

@end

#pragma mark - 

@implementation ObjectiveCEnumItemState

@synthesize startToken;
@synthesize endToken;
@synthesize data;

- (void)didBecomeCurrentStateForContext:(id)context {
	[super didBecomeCurrentStateForContext:context];
	self.startToken = nil;
	self.endToken = nil;
}

- (void)parseToken:(PKToken *)token {
	LogDebug(@"Matched %@.", token);
	if (!self.startToken) self.startToken = token;
	self.endToken = token;
}

@end
