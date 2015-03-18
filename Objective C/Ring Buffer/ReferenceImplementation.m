//
//  ReferenceImplementation.m
//  Ring Buffer
//
//  Created by Ben Voß on 6/12/2011.
//  Copyright (c) 2011. All rights reserved.
//

#import "ReferenceImplementation.h"

#include <assert.h>
#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>

@interface Queue : NSObject {
@private
	NSMutableArray* _array;
}

-(id)init;
- (void) enqueue:(id)anObject;
- (id)dequeue;
-(int)count;

@end

@implementation Queue

-(id)init {
	self = [super init];
	if (self) {
		_array = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) enqueue:(id)anObject {
    [_array addObject:anObject];
}

- (id)dequeue {
    if ([_array count] == 0) {
        return nil;
    }
    id queueObject = [_array objectAtIndex:0];
    [_array removeObjectAtIndex:0];
    return queueObject;
}

-(int)count {
	return (int)[_array count];
}

@end

@interface Producer : NSObject
{
@private
	NSThread* _thread;
	NSCondition* _condition;
	Queue* _list;
	int _size;
	int _numIterations;
}

-(id)initWith:(int)size numIterations:(int)numIterations;

-(void)produce:(Queue*)queue condition:(NSCondition*)condition;

@end

@implementation Producer

-(id) initWith:(int)size numIterations:(int)numIterations
{
	self = [super init];
	if (self) {
		_numIterations = numIterations;
		_size = size;
		
		_thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadCallback:) object:nil];
	}
	return self;
}

-(void) produce:(Queue*)list condition:(NSCondition*)condition {
	_condition = condition;
	_list = list;
	[_thread start];
}

-(void) threadCallback:(id)unused {
	for (int i = 0; i < _numIterations;) {
		[_condition lock];
		if ([_list count] < _size)
		{
			[_list enqueue:[NSNumber numberWithInt:i++]];
				
			[_condition signal];
		} else {
			[_condition wait];
		}
		[_condition unlock];
		
		//NSLog(@"P %d", i);
	}
}
@end

@interface Consumer : NSObject {
@private
	NSThread* _thread;
	Queue* _list;
	NSCondition* _condition;
	NSCondition* _completionEvent;
	int _numIterations;
}

-(id)initWith:(int)numIterations;

-(void)waitForCompletion;

-(void)consume:(Queue*)queue condition:(NSCondition*)condition;

@end

@implementation Consumer

-(id)initWith:(int)numIterations {
	self = [super init];
	if (self) {
		_numIterations = numIterations;
		_thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadCallback:) object:nil];
		_completionEvent = [[NSCondition alloc] init];
	}
	return self;
}

-(void)consume:(Queue*) list condition:(NSCondition*)condition {
	_condition = condition;
	_list = list;
	[_thread start];
}

-(void)threadCallback:(id)unused {
	
	for (int i = 0; i < _numIterations;) {
		int currentValue = 0;
		
		[_condition lock];
				
		if ([_list count] > 0) {
			NSNumber* number = [_list dequeue];

			currentValue = (int)number.integerValue;
				
			if (i != currentValue)
				NSLog(@"Numbers not in order - algorithm is broken");
				
			i++;
			[_condition signal];
		}
		else
			[_condition wait];

		[_condition unlock];

		//NSLog(@"C %d", i);
	}
	
	[_completionEvent lock];
	[_completionEvent signal];
	[_completionEvent unlock];
}

-(void) waitForCompletion {
	[_completionEvent lock];
	[_completionEvent wait];
	[_completionEvent unlock];
}
@end

@implementation ReferenceImplementation

-(void)runTest:(int)bufferSize numIterations:(int)numIterations {
	Producer* producer = [[Producer alloc] initWith:bufferSize numIterations:numIterations];
	Consumer* consumer = [[Consumer alloc] initWith:numIterations];
	Queue* list = [[Queue alloc] init];
	NSCondition* condition = [[NSCondition alloc] init];
	
	uint64_t start = mach_absolute_time();
		
	[consumer consume:list condition:condition];
	[producer produce:list condition:condition];
	
	[consumer waitForCompletion];
	
	uint64_t end = mach_absolute_time();
	
	uint64_t elapsed = end - start;
	Nanoseconds elapsedNano = AbsoluteToNanoseconds( *(AbsoluteTime *) &elapsed );
	uint64_t time = * (uint64_t *) &elapsedNano;
	
	NSLog(@"Reference implementation took %f", time / 1000000000.0);
}

@end
