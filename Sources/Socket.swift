#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
	import Darwin
#elseif os(Linux)
	import Glibc
#endif

struct Socket {
  static func read(_ socket:Int32, _ buffer: UnsafeMutableRawPointer, _ size:Int) -> Int {
    #if os(macOS) 
      return Darwin.read(socket, buffer, size) 
    #elseif os(Linux)
      return Glibc.read(socket, buffer, size) 
    #endif
  }
  
  static func write(_ socket:Int32, _ buffer: Array<UInt8>, _ size:Int) -> Int {
    #if os(macOS) 
      return Darwin.write(socket, buffer, size) 
    #elseif os(Linux)
      return Glibc.write(socket, buffer, size) 
    #endif
  }
  
  static func close(_ socket:Int32) -> Int32 {
    #if os(macOS) 
      return Darwin.close(socket) 
    #elseif os(Linux)
      return Glibc.close(socket)
    #endif
  }
}
