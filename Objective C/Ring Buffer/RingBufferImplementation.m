//
//  RingBufferImplementation.m
//  Ring Buffer
//
//  Created by Ben Voß on 6/12/2011.
//  Copyright (c) 2011. All rights reserved.
//

#import "RingBufferImplementation.h"

#include <assert.h>
#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>

@interface RingBuffer : NSObject {
@private
	// The producer and consumer pointers.  These fields are volatile so they are guaranteed to be written to memory
	// and the compiler and the JIT will not optimise these assignments out or re-order statements using the fields.
	// In addition the fields are surrounded by unused fields that reserve space in memory so that these pointers
	// occupy their own CPU cache lines with nothing else around them.  This avoids the CPUS contending on cache
	// writeback effects from other memory accesses.
	long p0, p1, p2, p3, p4, p5, p6, p7;		// Cache line padding - this avoids CPU cache writeback contention
	volatile int _producerPosition;
	long p8, p9, p10, p11, p12, p13, p14, p15;	// Cache line padding - this avoids CPU cache writeback contention

	long c0, c1, c2, c3, c4, c5, c6, c7;		// Cache line padding - this avoids CPU cache writeback contention
	volatile int _consumerPosition;
	long c8, c9, c10, c11, c12, c13, c14, c15;	// Cache line padding - this avoids CPU cache writeback contention

	// The ring buffer storage
	int* _buffer;
	
	// Bit mask for quickly implementing a modulus of the buffer pointers
	int _pointerModMask;
	int _bufferSize;
	
	// Cached copies of pointers used for batching
	int _lastKnownProducerPosition;// = -1;
	int _lastKnownConsumerPosition;// = -1;
}

	-(id)initWithSize:(int)size;
@end

@implementation RingBuffer

	// Initialises a new instance of a RingBuffer with the specified buffer size
	-(id)initWithSize:(int)size {
		self = [super init];
		if (self) {
			_bufferSize = 1 << (int)(floor(log(size - 1) + 1));				
			_pointerModMask = _bufferSize - 1;
		
			_buffer = malloc(_bufferSize * sizeof(int));
			
			_producerPosition = 0;
			_consumerPosition = 0;
			_lastKnownProducerPosition = -1;
			_lastKnownConsumerPosition = -1;
		}
		return self;
	}

// Gets the next value from the buffer.
// This method spins until a value is available.
-(int) get {
	// Only read the pointer if we know we have to - otherwise we
	// take advantage of batching.
	int c = _consumerPosition;
	while (c >= _lastKnownProducerPosition)
		_lastKnownProducerPosition = _producerPosition;
	
	int entry = _buffer[c & _pointerModMask];
	
	_consumerPosition = c + 1;
	
	return entry;
}

// Puts the specified value into the buffer.
// This method spins until there is space if the buffer.
-(void)put:(int)i {
	
	// Spin waiting for space to write to the buffer
	int p = _producerPosition;
	while (p - _bufferSize >= _lastKnownConsumerPosition)
		_lastKnownConsumerPosition = _consumerPosition;
	
	// Set the new value and clear the consumed flag
	_buffer[p & _pointerModMask] = i;
	
	_producerPosition = p + 1;
}

@end

@interface RBProducer : NSObject {
@private
	NSThread* _thread;
	RingBuffer* _ringBuffer;
	int _numIterations;
}

-(id)init:(int)numIterations;
-(void)produce:(RingBuffer*)ringBuffer;

@end

@implementation RBProducer

-(id)init:(int)numIterations {
	self = [super init];
	if (self) {
		_numIterations = numIterations;
		_thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadCallback:) object:nil];
	}
	return self;
}

-(void)produce:(RingBuffer*)ringBuffer {
	_ringBuffer = ringBuffer;
	[_thread start];
}

-(void)threadCallback:(id)unused {
	for (int i = 0; i < _numIterations; i++)
		[_ringBuffer put:i];
}

@end

@interface RBConsumer : NSObject {
@private
	NSThread* _thread;
	RingBuffer* _ringBuffer;
	NSCondition* _completionEvent;
	int _numIterations;
}
@end

@implementation RBConsumer

-(id)init:(int)numIterations {
	self = [super init];
	if (self) {
		_completionEvent = [[NSCondition alloc] init];
		_numIterations = numIterations;
		_thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadCallback:) object:nil];
	}
	return self;
}

-(void)consume:(RingBuffer*)ringBuffer {
	_ringBuffer = ringBuffer;
	[_thread start];
}

-(void)threadCallback:(id)unused {
	for (int i = 0; i < _numIterations; i++)
	{
		int currentValue = [_ringBuffer get];
		
		if (i != currentValue)
			NSLog(@"Numbers not in order - algorithm is broken");
		
	}
	
	[_completionEvent lock];
	[_completionEvent signal];
	[_completionEvent unlock];
}

-(void)waitForCompletion {
	[_completionEvent lock];
	[_completionEvent wait];
	[_completionEvent unlock];
}

@end


@implementation RingBufferImplementation

-(void)runTest:(int)bufferSize numIterations:(int)numIterations {
	RBProducer* producer = [[RBProducer alloc] init:numIterations];
	RBConsumer* consumer = [[RBConsumer alloc] init:numIterations];
	RingBuffer* ringBuffer = [[RingBuffer alloc] initWithSize:bufferSize];
	
	uint64_t start = mach_absolute_time();
	
	[consumer consume:ringBuffer];
	[producer produce:ringBuffer];
	
	[consumer waitForCompletion];
	
	uint64_t end = mach_absolute_time();
	
	uint64_t elapsed = end - start;
	Nanoseconds elapsedNano = AbsoluteToNanoseconds( *(AbsoluteTime *) &elapsed );
	uint64_t time = * (uint64_t *) &elapsedNano;
	
	NSLog(@"RingBuffer implementation took %f", time / 1000000000.0);
}

@end
