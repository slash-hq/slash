//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

class Request {
    
    enum HttpVersion { case http10, http11 }
    
    var httpVersion = HttpVersion.http10
    
    var method = ""
    
    var path = ""
    
    var query = [(String, String)]()
    
    var headers = [(String, String)]()
    
    var body = [UInt8]()
    
    var contentLength = 0
    
    func hasToken(_ token: String, forHeader headerName: String) -> Bool {
        guard let (_, value) = headers.filter({ $0.0 == headerName }).first else {
            return false
        }
        return value
            .components(separatedBy: ",")
            .filter({ $0.trimmingCharacters(in: .whitespaces).lowercased() == token })
            .count > 0
    }
}

class Response {
    
    init() { }
    
    init(_ status: Status = Status.ok) {
        self.status = status.rawValue
    }
    
    init(_ status: Int = Status.ok.rawValue) {
        self.status = status
    }
    
    init(_ body: Array<UInt8>) {
        self.body.append(contentsOf: body)
    }
    
    init(_ body: ArraySlice<UInt8>) {
        self.body.append(contentsOf: body)
    }
    
    var status = Status.ok.rawValue
    
    var headers = [(String, String)]()
    
    var body = [UInt8]()
    
    var processingSuccesor: IncomingDataProcessor? = nil
}

class TextResponse: Response {
    
    init(_ status: Int = Status.ok.rawValue, _ text: String) {
        super.init(status)
        self.headers.append(("Content-Type", "text/plain"))
        self.body = [UInt8](text.utf8)
    }
}

class HtmlResponse: Response {
    
    init(_ status: Int = Status.ok.rawValue, _ text: String) {
        super.init(status)
        self.headers.append(("Content-Type", "text/html"))
        self.body = [UInt8](text.utf8)
    }
}

enum Status: Int {
    case `continue` = 100
    case switchingProtocols = 101
    case ok = 200
    case created = 201
    case accepted = 202
    case noContent = 204
    case resetContent = 205
    case partialContent = 206
    case movedPerm = 301
    case notModified = 304
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
}

extension UInt8 {
    
    static var
    lf: UInt8 = 10,
    cr: UInt8 = 13,
    space: UInt8 = 32,
    colon: UInt8 = 58,
    ampersand: UInt8 = 38,
    lessThan: UInt8 = 60,
    greaterThan: UInt8 = 62,
    slash: UInt8 = 47,
    equal: UInt8 = 61,
    doubleQuotes: UInt8 = 34,
    openingParenthesis: UInt8 = 40,
    closingParenthesis: UInt8 = 41,
    comma: UInt8 = 44
}

enum AsyncError: Error {
    case parse(String)
    case async(String)
    case socketCreation(String)
    case setReUseAddr(String)
    case setNoSigPipeFailed(String)
    case setNonBlockFailed(String)
    case setReuseAddrFailed(String)
    case bindFailed(String)
    case listenFailed(String)
    case writeFailed(String)
    case getPeerNameFailed(String)
    case convertingPeerNameFailed
    case getNameInfoFailed(String)
    case acceptFailed(String)
    case readFailed(String)
    case httpError(String)
}

protocol TcpServer {
    
    init(_ port: in_port_t) throws
    
    func wait(_ callback: ((TcpServerEvent) -> Void)) throws
    
    func write(_ socket: Int32, _ data: Array<UInt8>, _ done: @escaping (() -> TcpWriteDoneAction)) throws
    
    func finish(_ socket: Int32)
}

enum TcpWriteDoneAction {
    
    case `continue`
    
    case terminate
}

enum TcpServerEvent {
    
    case connect(String, Int32)
    
    case disconnect(String, Int32)
    
    case data(String, Int32, ArraySlice<UInt8>)
}

class HttpIncomingDataPorcessor: Hashable, IncomingDataProcessor {
    
    private enum State {
        case waitingForHeaders
        case waitingForBody
    }
    
    private var state = State.waitingForHeaders
    
    private let socket: Int32
    private var buffer = Array<UInt8>()
    private var request = Request()
    private let callback: ((Request) throws -> Void)
    
    init(_ socket: Int32, _ closure: @escaping ((Request) throws -> Void)) {
        self.socket = socket
        self.callback = closure
    }
    
    static func == (lhs: HttpIncomingDataPorcessor, rhs: HttpIncomingDataPorcessor) -> Bool {
        return lhs.socket == rhs.socket
    }
    
    var hashValue: Int { return Int(self.socket) }
    
    func process(_ chunk: ArraySlice<UInt8>) throws {
        
        switch self.state {
            
        case .waitingForHeaders:
            
            guard self.buffer.count + chunk.count < 4096 else {
                throw AsyncError.parse("Headers size exceeds that limit.")
            }
            
            var iterator = chunk.makeIterator()
            
            while let byte = iterator.next() {
                if byte != UInt8.cr {
                    buffer.append(byte)
                }
                if buffer.count >= 2 && buffer[buffer.count-1] == UInt8.lf && buffer[buffer.count-2] == UInt8.lf {
                    self.buffer.removeLast(2)
                    self.request = try self.consumeHeader(buffer)
                    self.buffer.removeAll(keepingCapacity: true)
                    let left = [UInt8](iterator)
                    self.state = .waitingForBody
                    try self.process(left[0..<left.count])
                    break
                }
            }
            
        case .waitingForBody:
            
            guard self.request.body.count + chunk.count <= request.contentLength else {
                throw AsyncError.parse("Peer sent more data then required ('Content-Length' = \(request.contentLength).")
            }
            
            request.body.append(contentsOf: chunk)
            
            if request.body.count == request.contentLength {
                self.state = .waitingForHeaders
                try self.callback(request)
            }
        }
    }
    
    private func consumeHeader(_ data: [UInt8]) throws -> Request {
        
        let lines = data.split(separator: UInt8.lf)
        
        guard let requestLine = lines.first else {
            throw AsyncError.httpError("No status line.")
        }
        
        let requestLineTokens = requestLine.split(separator: UInt8.space)
        
        guard requestLineTokens.count >= 3 else {
            throw AsyncError.httpError("Invalid status line.")
        }
        
        let request = Request()
        
        if requestLineTokens[2] == [0x48, 0x54,  0x54,  0x50, 0x2f, 0x31, 0x2e, 0x30] {
            request.httpVersion = .http10
        } else if requestLineTokens[2] == [0x48, 0x54,  0x54,  0x50, 0x2f, 0x31, 0x2e, 0x31] {
            request.httpVersion = .http11
        } else {
            throw AsyncError.parse("Invalid http version: \(requestLineTokens[2])")
        }
        
        request.headers = lines
            .dropFirst()
            .map { line in
                let headerTokens = line.split(separator: UInt8.colon, maxSplits: 1)
                if let name = headerTokens.first, let value = headerTokens.last {
                    if let nameString = String(bytes: name, encoding: .ascii),
                        let valueString = String(bytes: value, encoding: .ascii) {
                        return (nameString.lowercased(), valueString.trimmingCharacters(in: .whitespaces))
                    }
                }
                return ("", "")
        }
        
        if let (_, value) = request.headers
            .filter({ $0.0 == "content-length" })
            .first {
            guard let contentLength = Int(value) else {
                throw AsyncError.parse("Invalid 'Content-Length' header value \(value).")
            }
            request.contentLength = contentLength
        }
        
        guard let method = String(bytes: requestLineTokens[0], encoding: .ascii) else {
            throw AsyncError.parse("Invalid 'method' value \(requestLineTokens[0]).")
        }
        
        request.method = method
        
        guard let path = String(bytes: requestLineTokens[1], encoding: .ascii) else {
            throw AsyncError.parse("Invalid 'path' value \(requestLineTokens[1]).")
        }
        
        let queryComponents = path.components(separatedBy: "?")
        
        if queryComponents.count > 1, let first = queryComponents.first, let last = queryComponents.last {
            request.path = first
            request.query = last
                .components(separatedBy: "&")
                .reduce([(String, String)]()) { (c, s) -> [(String, String)] in
                    let tokens = s.components(separatedBy: "=")
                    if let name = tokens.first, let value = tokens.last {
                        if let nameDecoded = name.removingPercentEncoding, let valueDecoded = value.removingPercentEncoding {
                            return c + [(nameDecoded, tokens.count > 1 ? valueDecoded : "")]
                        }
                    }
                    return c
            }
        } else {
            request.path = path
        }
        
        return request
    }
}

class Server {
    
    private var processors = [Int32 : IncomingDataProcessor]()
    
    private let server: TcpServer
    
    init(_ port: in_port_t = 8080) throws {
        #if os(Linux)
            self.server = try LinuxAsyncServer(port)
        #else
            self.server = try MacOSAsyncTCPServer(port)
        #endif
    }
    
    func serve(_ callback: @escaping ((request: Request, responder: ((Response) -> Void))) -> Void) throws {
        
        try self.server.wait { event in
            
            switch event {
                
            case .connect(_, let socket):
                
                self.processors[socket] = HttpIncomingDataPorcessor(socket) { request in
                    callback((request, { response in
                        let keepIOSession = self.supportsKeepAlive(request.headers) || request.httpVersion == .http11
                        var data = [UInt8]()
                        data.reserveCapacity(1024)
                        data.append(contentsOf: [UInt8]("HTTP/\(request.httpVersion == .http10 ? "1.0" : "1.1") \(response.status) OK\r\n".utf8))
                        for (name, value) in response.headers {
                            data.append(contentsOf: [UInt8]("\(name): \(value)\r\n".utf8))
                        }
                        if (keepIOSession) {
                            data.append(contentsOf: [UInt8]("Connection: keep-alive\r\n".utf8))
                        }
                        data.append(contentsOf: [UInt8]("Content-Length: \(response.body.count)\r\n".utf8))
                        data.append(contentsOf: [13, 10])
                        data.append(contentsOf: response.body)
                        do {
                            try self.server.write(socket, data) {
                                if let sucessor = response.processingSuccesor {
                                    self.processors[socket] = sucessor
                                    return .continue
                                }
                                return keepIOSession ? .continue : .terminate
                            }
                        } catch {
                            self.processors.removeValue(forKey: socket)
                        }
                    }))
                }
                
            case .disconnect(_, let socket):
                
                self.processors.removeValue(forKey: socket)
                
            case .data(_, let socket, let chunk):
                
                do {
                    try self.processors[socket]?.process(chunk)
                } catch {
                    self.processors.removeValue(forKey: socket)
                    self.server.finish(socket)
                }
            }
        }
    }
    
    private func supportsKeepAlive(_ headers: Array<(String, String)>) -> Bool {
        if let (_, value) = headers.filter({ $0.0 == "connection" }).first {
            return "keep-alive" == value.trimmingCharacters(in: CharacterSet.whitespaces)
        }
        return false
    }
    
    private func closeConnection(_ headers: Array<(String, String)>) -> Bool {
        if let (_, value) = headers.filter({ $0.0 == "connection" }).first {
            return "close" == value.trimmingCharacters(in: CharacterSet.whitespaces)
        }
        return false
    }
}

protocol IncomingDataProcessor {
    
    func process(_ chunk: ArraySlice<UInt8>) throws
}

extension Process {
    
    static var pid: Int {
        return Int(getpid())
    }
    
    static var tid: UInt64 {
        #if os(Linux)
            return UInt64(pthread_self())
        #else
            var tid: __uint64_t = 0
            pthread_threadid_np(nil, &tid);
            return UInt64(tid)
        #endif
    }
    
    static var error: String {
        return String(cString: UnsafePointer(strerror(errno)))
    }
}

class MacOSAsyncTCPServer: TcpServer {
    
    private var backlog = Dictionary<Int32, Array<(chunk: [UInt8], done: (() -> TcpWriteDoneAction))>>()
    private var peers = Set<Int32>()
    
    private let kernelQueue: KernelQueue
    private let server: UInt
    
    required init(_ port: in_port_t = 8080) throws {
        
        self.kernelQueue = try KernelQueue()
        
        self.server = UInt(try MacOSAsyncTCPServer.nonBlockingSocketForListenening(port))
        
        self.kernelQueue.subscribe(server, .read)
    }
    
    func write(_ socket: Int32, _ data: Array<UInt8>, _ done: @escaping (() -> TcpWriteDoneAction)) throws {
        
        let result = Socket.write(socket, data, data.count)
        
        if result == -1 {
            defer { self.finish(socket) }
            throw AsyncError.writeFailed(Process.error)
        }
        
        if result == data.count {
            if done() == .terminate {
                self.finish(socket)
            }
            return
        }
        
        self.backlog[socket]?.append(([UInt8](data[result..<data.count]), done))
        self.kernelQueue.resume(UInt(socket), .write)
    }
    
    func wait(_ callback: ((TcpServerEvent) -> Void)) throws {
        try self.kernelQueue.wait { signal in
            switch signal.event {
            case .read:
                if signal.ident == self.server {
                    let client = try MacOSAsyncTCPServer.acceptAndConfigureClientSocket(Int32(signal.ident))
                    self.peers.insert(client)
                    self.backlog[Int32(client)] = []
                    kernelQueue.subscribe(UInt(client), .read)
                    kernelQueue.subscribe(UInt(client), .write)
                    kernelQueue.pause(UInt(client), .write)
                    callback(.connect("", Int32(client)))
                } else {
                    var chunk = [UInt8](repeating: 0, count: signal.data)
                    let result = Socket.read(Int32(signal.ident), &chunk, signal.data)
                    if result <= 0 {
                        finish(Int32(signal.ident))
                        callback(.disconnect("", Int32(signal.ident)))
                    } else {
                        callback(.data("", Int32(signal.ident), chunk[0..<result]))
                    }
                }
            case .write:
                while let backlogElement = self.backlog[Int32(signal.ident)]?.first {
                    var chunk = backlogElement.chunk
                    let result = Socket.write(Int32(signal.ident), chunk, min(chunk.count, signal.data))
                    if result == -1 {
                        finish(Int32(signal.ident))
                        callback(.disconnect("", Int32(signal.ident)))
                        return
                    }
                    if result < chunk.count {
                        let leftData = [UInt8](chunk[result..<chunk.count])
                        self.backlog[Int32(signal.ident)]?.remove(at: 0)
                        self.backlog[Int32(signal.ident)]?.insert((chunk: leftData, done: backlogElement.done), at: 0)
                        return
                    }
                    self.backlog[Int32(signal.ident)]?.removeFirst()
                    if backlogElement.done() == .terminate {
                        self.finish(Int32(signal.ident))
                        callback(.disconnect("", Int32(signal.ident)))
                        return
                    }
                }
                self.kernelQueue.pause(signal.ident, .write)
            case .error:
                if signal.ident == self.server {
                    throw AsyncError.async(Process.error)
                } else {
                    self.finish(Int32(signal.ident))
                    callback(.disconnect("", Int32(signal.ident)))
                }
            }
        }
    }
    
    deinit {
        closeAllOpenedSockets()
    }
    
    func finish(_ socket: Int32) {
        self.backlog[socket] = []
        self.peers.remove(socket)
        let _ = Socket.close(socket)
    }
    
    func closeAllOpenedSockets() {
        for client in self.peers {
            let _ = Socket.close(client)
        }
        self.peers.removeAll(keepingCapacity: true)
        let _ = Socket.close(Int32(server))
    }
    
    static func nonBlockingSocketForListenening(_ port: in_port_t = 8080) throws -> Int32 {
        
        let server = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        
        guard server != -1 else {
            throw AsyncError.socketCreation(Process.error)
        }
        
        var value: Int32 = 1
        if Darwin.setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            defer { let _ = Socket.close(server) }
            throw AsyncError.setReuseAddrFailed(Process.error)
        }
        
        try setSocketNonBlocking(server)
        try setSocketNoSigPipe(server)
        
        var addr = anyAddrForPort(port)
        
        if withUnsafePointer(to: &addr, { Darwin.bind(server, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in>.size)) }) == -1 {
            defer { let _ = Socket.close(server) }
            throw AsyncError.bindFailed(Process.error)
        }
        
        if Darwin.listen(server, SOMAXCONN) == -1 {
            defer { let _ = Socket.close(server) }
            throw AsyncError.listenFailed(Process.error)
        }
        
        return server
    }
    
    static func acceptAndConfigureClientSocket(_ socket: Int32) throws -> Int32 {
        
        guard case let client = Darwin.accept(socket, nil, nil), client != -1 else {
            throw AsyncError.acceptFailed(Process.error)
        }
        
        try self.setSocketNonBlocking(client)
        try self.setSocketNoSigPipe(client)
        
        return client
    }
    
    static func anyAddrForPort(_ port: in_port_t) -> sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: in_addr_t(0))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        return addr
    }
    
    static func setSocketNonBlocking(_ socket: Int32) throws {
        if Darwin.fcntl(socket, F_SETFL, Darwin.fcntl(socket, F_GETFL, 0) | O_NONBLOCK) == -1 {
            throw AsyncError.setNonBlockFailed(Process.error)
        }
    }
    
    static func setSocketNoSigPipe(_ socket: Int32) throws {
        var value = 1
        if Darwin.setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            throw AsyncError.setNoSigPipeFailed(Process.error)
        }
    }
}

class KernelQueue {
    
    private var events = Array<kevent>(repeating: kevent(), count: 256)
    private var changes = Array<kevent>()
    
    private let queue: Int32
    
    enum Subscription { case read, write }
    enum Event { case read, write, error }
    
    init() throws {
        guard case let queue = kqueue(), queue != -1 else {
            throw AsyncError.async(Process.error)
        }
        self.queue = queue
    }
    
    func subscribe(_ ident: UInt, _ event: Subscription) {
        switch event {
        case .read  : changes.append(self.event(UInt(ident), Int16(EVFILT_READ), UInt16(EV_ADD) | UInt16(EV_ENABLE)))
        case .write : changes.append(self.event(UInt(ident), Int16(EVFILT_WRITE), UInt16(EV_ADD) | UInt16(EV_ENABLE)))
        }
    }
    
    func unsubscribe(_ ident: UInt, _ event: Subscription) {
        switch event {
        case .read  : changes.append(self.event(UInt(ident), Int16(EVFILT_READ), UInt16(EV_DELETE)))
        case .write : changes.append(self.event(UInt(ident), Int16(EVFILT_WRITE), UInt16(EV_DELETE)))
        }
    }
    
    func pause(_ ident: UInt, _ event: Subscription) {
        switch event {
        case .read  : changes.append(self.event(UInt(ident), Int16(EVFILT_READ), UInt16(EV_DISABLE)))
        case .write : changes.append(self.event(UInt(ident), Int16(EVFILT_WRITE), UInt16(EV_DISABLE)))
        }
    }
    
    func resume(_ ident: UInt, _ event: Subscription) {
        switch event {
        case .read  : changes.append(self.event(UInt(ident), Int16(EVFILT_READ), UInt16(EV_ENABLE)))
        case .write : changes.append(self.event(UInt(ident), Int16(EVFILT_WRITE), UInt16(EV_ENABLE)))
        }
    }
    
    private func event(_ ident: UInt, _ filter: Int16, _ flags: UInt16) -> kevent {
        return kevent(ident: ident, filter: filter, flags: flags, fflags: 0, data: 0, udata: nil)
    }
    
    func wait(_ callback: (_ tuple: (event: Event, ident: UInt, data: Int)) throws -> (Void)) throws {
        
        if !changes.isEmpty {
            if kevent(self.queue, &changes, Int32(changes.count), nil, 0, nil) == -1 {
                throw AsyncError.async(Process.error)
            }
        }
        
        self.changes.removeAll(keepingCapacity: true)
        
        guard case let count = kevent(self.queue, nil, 0, &events, Int32(events.count), nil), count != -1 else {
            throw AsyncError.async(Process.error)
        }
        
        for event in events[0..<Int(count)] {
            
            if Int32(event.flags) & EV_EOF != 0 || Int32(event.flags) & EV_ERROR != 0 {
                try callback((.error, event.ident, 0))
                continue
            }
            if Int32(event.filter) == EVFILT_READ {
                try callback((.read, event.ident, event.data))
                continue
            }
            if Int32(event.filter) == EVFILT_WRITE {
                try callback((.write, event.ident, event.data))
                continue
            }
        }
    }
}


