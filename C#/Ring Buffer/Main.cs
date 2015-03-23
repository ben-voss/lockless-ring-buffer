using System;

namespace RingBuffer
{
	class MainClass
	{
		
		private const int bufferSize = 1024;
		private const int numIterations = 10000000;
		
		public static void Main (string[] args)
		{
			Console.WriteLine ("Tests will execute {0:0,0} iterations and a buffer size of {1}", numIterations, bufferSize);
			Console.WriteLine ("Press Enter to start.");
			Console.ReadLine();
			Console.WriteLine("Running...");
			
			new ReferenceImplementation().RunTest(bufferSize, numIterations);
			
			new RingBufferImplementation().RunTest(bufferSize, numIterations);
			
			Console.WriteLine("Done");
			Console.ReadLine();
		}
	}
}

