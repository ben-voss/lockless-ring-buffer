using System;
using System.Threading;
using System.Runtime.InteropServices;

namespace RingBuffer
{
	public class RingBufferImplementation
	{
		
		[StructLayout(LayoutKind.Sequential)]  // Force a field layout as ordered in the code
		private class RingBuffer {
			
			// The producer and consumer pointers.  These fields are volatile so they are guaranteed to be written to memory
			// and the compiler and the JIT will not optimise these assignments out or re-order statements using the fields.
			// In addition the fields are surrounded by unused fields that reserve space in memory so that these pointers
			// occupy their own CPU cache lines with nothing else around them.  This avoids the CPUS contending on cache
			// writeback effects from other memory accesses.
#pragma warning disable 0169, 0414
			private long p0, p1, p2, p3, p4, p5, p6, p7;		// Cache line padding - this avoids CPU cache writeback contention
			private volatile int _producerPosition = 0;
			private long p8, p9, p10, p11, p12, p13, p14, p15;	// Cache line padding - this avoids CPU cache writeback contention

			private long c0, c1, c2, c3, c4, c5, c6, c7;		// Cache line padding - this avoids CPU cache writeback contention
			private volatile int _consumerPosition = 0;
			private long c8, c9, c10, c11, c12, c13, c14, c15;	// Cache line padding - this avoids CPU cache writeback contention
#pragma warning restore 0169, 0414
			
			// The ring buffer storage
			private readonly int[] _buffer;
		
			// Bit mask for quickly implementing a modulus of the buffer pointers
			private readonly int _pointerModMask;
			private readonly int _bufferSize;
			
			// Cached copies of pointers used for batching
			private int _lastKnownProducerPosition = -1;
			private int _lastKnownConsumerPosition = -1;
			
			/// <summary>
			/// Initialises a new instance of a RingBuffer with the specified buffer size
			/// </summary>
			/// <param name="size">
			/// A <see cref="System.Int32"/>
			/// </param>
			public RingBuffer(int size) {
				_bufferSize = 1 << (int)(Math.Floor(Math.Log(size - 1, 2) + 1));				
        		_pointerModMask = _bufferSize - 1;
				
				_buffer = new int[_bufferSize];
			}
			
			/// <summary>
			/// Gets the next value from the buffer.
			/// </summary>
			/// <remarks>
			/// This method spins until a value is available.
			/// </remarks>
			public int Get() {
				// Only read the pointer if we know we have to - otherwise we
				// take advantage of batching.
				int c = _consumerPosition;
				while (c >= _lastKnownProducerPosition)
					_lastKnownProducerPosition = _producerPosition;
				
				int entry = _buffer[c & _pointerModMask];
				
				_consumerPosition = c + 1;
				
				return entry;
			}
			
			/// <summary>
			/// Puts the specified value into the buffer.
			/// </summary>
			/// <remarks>
			/// This method spins until there is space if the buffer.
			/// </remarks>
			public void Put(int i) {
				
				// Spin waiting for space to write to the buffer
				int p = _producerPosition;
				while (p - _bufferSize >= _lastKnownConsumerPosition)
					_lastKnownConsumerPosition = _consumerPosition;

				// Set the new value and clear the consumed flag
				_buffer[p & _pointerModMask] = i;

				_producerPosition = p + 1;
			}
		}
		
		private class Producer
		{
			private readonly Thread _thread;
			private RingBuffer _ringBuffer;
			private readonly int _numIterations;
			
			public Producer (int numIterations)
			{
				_numIterations = numIterations;
				_thread = new Thread(ThreadCallback);
			}
			
			public void Produce(RingBuffer ringBuffer) {
				_ringBuffer = ringBuffer;
				_thread.Start();
			}
			
			private void ThreadCallback() {
				for (int i = 0; i < _numIterations; i++)
					_ringBuffer.Put(i);
			}
		}
		
		private class Consumer
		{
			private readonly Thread _thread;
			private RingBuffer _ringBuffer;
			private readonly ManualResetEvent _completionEvent = new ManualResetEvent(false);
			private readonly int _numIterations;
			
			public Consumer (int numIterations)
			{
				_numIterations = numIterations;
				_thread = new Thread(ThreadCallback);
			}
			
			public void Consume(RingBuffer ringBuffer) {
				_ringBuffer = ringBuffer;
				_thread.Start();
			}
			
			private void ThreadCallback() {
				for (int i = 0; i < _numIterations; i++)
				{
					int currentValue = _ringBuffer.Get();
					
					if (i != currentValue)
						Console.WriteLine("Numbers not in order - algorithm is broken");

				}
				
				_completionEvent.Set();
			}
			
			public void WaitForCompletion() {
				_completionEvent.WaitOne();
			}
		}
				
		public RingBufferImplementation ()
		{
		}
		
		public void RunTest(int size, int numIterations) {
			Producer producer = new Producer(numIterations);
			Consumer consumer = new Consumer(numIterations);
			RingBuffer ringBuffer = new RingBuffer(size);
			
			DateTime start = DateTime.UtcNow;
			
			consumer.Consume(ringBuffer);
			producer.Produce(ringBuffer);
			
			consumer.WaitForCompletion();
			
			DateTime end = DateTime.UtcNow;
			
			Console.WriteLine("RingBuffer implementation took " + (end - start));
		}
		
	}
}

