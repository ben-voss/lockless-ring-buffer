using System;
using System.Threading;
using System.Collections.Generic;

namespace RingBuffer
{
	public class ReferenceImplementation
	{
		private class Producer
		{
			private readonly Thread _thread;
			private Queue<int> _list;
			private readonly int _size;
			private readonly int _numIterations;
			
			public Producer (int size, int numIterations)
			{
				_numIterations = numIterations;
				_size = size;
				_thread = new Thread(ThreadCallback);
			}
			
			public void Produce(Queue<int> list) {
				_list = list;
				_thread.Start();
			}
			
			private void ThreadCallback() {
				for (int i = 0; i < _numIterations;) {
					lock(_list) {
						if (_list.Count < _size)
						{
							_list.Enqueue(i++);
							Monitor.PulseAll(_list);
						} else {
							Monitor.Wait(_list);
						}
					}
					
					//Console.WriteLine("P "+ i);
				}
			}
		}
		
		private class Consumer
		{
			private readonly Thread _thread;
			private Queue<int> _list;
			private readonly ManualResetEvent _completionEvent = new ManualResetEvent(false);
			private readonly int _numIterations;
			
			public Consumer (int numIterations)
			{
				_numIterations = numIterations;
				_thread = new Thread(ThreadCallback);
			}
			
			public void Consume(Queue<int> list) {
				_list = list;
				_thread.Start();
			}
			
			private void ThreadCallback() {
					
				for (int i = 0; i < _numIterations;) {
					int currentValue = 0;
					
					lock(_list) {
						if (_list.Count > 0) {
							currentValue = _list.Dequeue();
							
							if (i != currentValue)
								Console.WriteLine("Numbers not in order - algorithm is broken");
							
							i++;
							Monitor.PulseAll(_list);
						}
						else
							Monitor.Wait(_list);
					}
					
					
					//Console.WriteLine("C " + i);
				}
				
				_completionEvent.Set();
			}
			
			public void WaitForCompletion() {
				_completionEvent.WaitOne();
			}
		}
		
		public ReferenceImplementation ()
		{
		}
				
		public void RunTest(int size, int numIterations) {
			Producer producer = new Producer(size, numIterations);
			Consumer consumer = new Consumer(numIterations);
			Queue<int> list = new Queue<int>();
			
			DateTime start = DateTime.UtcNow;
			
			consumer.Consume(list);
			producer.Produce(list);
			
			consumer.WaitForCompletion();
			
			DateTime end = DateTime.UtcNow;
			
			Console.WriteLine("Reference implementation took " + (end - start));
		}
	}
}

