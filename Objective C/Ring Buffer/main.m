//
//  main.m
//  Ring Buffer
//
//  Created by Ben Voß on 6/12/2011.
//  Copyright (c) 2011. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReferenceImplementation.h"
#import "RingBufferImplementation.h"

const int bufferSize = 1024;
const int numIterations = 10000000;


int main (int argc, const char * argv[])
{

	@autoreleasepool {
	    
	    // insert code here...
	    NSLog(@"Tests will execute %d iterations and a buffer size of %d", numIterations, bufferSize);
	    NSLog(@"Press Enter to start.");

		NSLog(@"Running...");
		
		[[[ReferenceImplementation alloc] init] runTest:bufferSize numIterations:numIterations];
		
		[[[RingBufferImplementation alloc] init] runTest:bufferSize numIterations:numIterations];
		
		NSLog(@"Done");		
	}
    return 0;
}

