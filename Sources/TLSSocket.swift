//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

#if os(OSX) || os(iOS)

enum TLSSocketError: Error {
    case error(String)
}

class TLSSocket {
    
    private var socket: Int32
    private let sslContext: SSLContext
    
    init(_ address: String, port: Int = 443) throws {
        
        guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
            throw TLSSocketError.error("SSLCreateContext returned null.")
        }
        
        self.sslContext = context
        
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        
        guard socket != -1 else {
            throw TLSSocketError.error("Darwin.socket failed: \(errno)")
        }
        
        self.socket = socket
        
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        
        guard inet_pton(AF_INET, address, &(addr.sin_addr)) == 1 else {
            let _ = Darwin.close(self.socket)
            throw TLSSocketError.error("inet_pton failed.")
        }
        
        if withUnsafePointer(to: &addr, {
            Darwin.connect(socket, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in>.size))
        }) == -1 {
            let _ = Darwin.close(self.socket)
            throw TLSSocketError.error("Darwin.connect failed: \(errno)")
        }
        
        SSLSetIOFuncs(context, sslRead, sslWrite)
        
        guard SSLSetConnection(context, &self.socket) == noErr else {
            let _ = Darwin.close(self.socket)
            throw TLSSocketError.error("SSLSetConnection failed.")
        }
        
        let handshakeResult = SSLHandshake(context)
        
        guard handshakeResult == noErr else {
            let _ = Darwin.close(self.socket)
            throw TLSSocketError.error("SSLHandshake failed: \(handshakeResult)")
        }
    }
    
    func close() {
        SSLClose(self.sslContext)
        let _ = Darwin.close(self.socket)
    }

    func writeData(_ data: [UInt8]) throws {
        var processed = 0
        let result = SSLWrite(self.sslContext, data, data.count, &processed)
        guard result == noErr else {
            throw TLSSocketError.error("SSLWrite failed: \(result)")
        }
    }
    
    func readData() throws -> [UInt8] {
        var processed = 0
        var data = [UInt8](repeating: 0, count: 1024)
        let result = SSLRead(self.sslContext, &data, data.count, &processed)
        guard result == noErr else {
            throw TLSSocketError.error("SSLRead failed: \(result)")
        }
        data.removeLast(data.count - processed)
        return data
    }
}

func sslRead(_ socketRef: SSLConnectionRef, _ data: UnsafeMutableRawPointer, _ length: UnsafeMutablePointer<Int>) -> OSStatus {
    let socket = socketRef.load(as: Int32.self)
    var n = 0
    while n < length.pointee {
        let result = read(socket, data + n, length.pointee - n)
        if result <= 0 {
            if result == Int(ENOENT) {
                return errSSLClosedGraceful
            }
            if result == Int(ECONNRESET) {
                return errSSLClosedAbort
            }
            return OSStatus(ioErr)
        }
        n += result
    }
    length.pointee = n
    return noErr
}

func sslWrite(_ socketRef: SSLConnectionRef, _ data: UnsafeRawPointer, _ length: UnsafeMutablePointer<Int>) -> OSStatus {
    let socket = socketRef.load(as: Int32.self)
    var n = 0
    while n < length.pointee {
        let result = write(socket, data + n, length.pointee - n)
        if result <= 0 {
            if result == Int(EPIPE) {
                return errSSLClosedAbort
            }
            if result == Int(ECONNRESET) {
                return errSSLClosedAbort
            }
            return OSStatus(ioErr)
        }
        n += result
    }
    length.pointee = n
    return noErr
}

#endif
