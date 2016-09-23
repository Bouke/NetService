#if os(OSX)
    import var Darwin.errno
    import func Darwin.gethostname
#else
    import var Glibc.errno
    import func Glibc.gethostname
#endif

import struct Foundation.Data
import Cifaddrs

struct POSIXError: Error {
    let code: Code
    let file: String
    let line: Int
    let column: Int
    let function: String

    init(code: Code? = nil, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        self.code = code ?? Code(rawValue: errno)!
        self.file = file
        self.line = line
        self.column = column
        self.function = function
    }

    enum Code: Int32 {
        case EPERM = 1 // Operation not permitted
        case ENOENT = 2 // No such file or directory
        case ESRCH = 3 // No such process
        case EINTR = 4 // Interrupted system call
        case EIO = 5 // I/O error
        case ENXIO = 6 // No such device or address
        case E2BIG = 7 // Argument list too long
        case ENOEXEC = 8 // Exec format error
        case EBADF = 9 // Bad file number
        case ECHILD = 10 // No child processes
        case EAGAIN = 11 // Try again
        case ENOMEM = 12 // Out of memory
        case EACCES = 13 // Permission denied
        case EFAULT = 14 // Bad address
        case ENOTBLK = 15 // Block device required
        case EBUSY = 16 // Device or resource busy
        case EEXIST = 17 // File exists
        case EXDEV = 18 // Cross-device link
        case ENODEV = 19 // No such device
        case ENOTDIR = 20 // Not a directory
        case EISDIR = 21 // Is a directory
        case EINVAL = 22 // Invalid argument
        case ENFILE = 23 // File table overflow
        case EMFILE = 24 // Too many open files
        case ENOTTY = 25 // Not a typewriter
        case ETXTBSY = 26 // Text file busy
        case EFBIG = 27 // File too large
        case ENOSPC = 28 // No space left on device
        case ESPIPE = 29 // Illegal seek
        case EROFS = 30 // Read-only file system
        case EMLINK = 31 // Too many links
        case EPIPE = 32 // Broken pipe
        case EDOM = 33 // Math argument out of domain of func
        case ERANGE = 34 // Math result not representable
        case EDEADLK = 35 // Resource deadlock would occur
        case ENAMETOOLONG = 36 // File name too long
        case ENOLCK = 37 // No record locks available
        case ENOSYS = 38 // Function not implemented
        case ENOTEMPTY = 39 // Directory not empty
        case ELOOP = 40 // Too many symbolic links encountered
        case ENOMSG = 42 // No message of desired type
        case EIDRM = 43 // Identifier removed
        case ECHRNG = 44 // Channel number out of range
        case EL2NSYNC = 45 // Level 2 not synchronized
        case EL3HLT = 46 // Level 3 halted
        case EL3RST = 47 // Level 3 reset
        case ELNRNG = 48 // Link number out of range
        case EUNATCH = 49 // Protocol driver not attached
        case ENOCSI = 50 // No CSI structure available
        case EL2HLT = 51 // Level 2 halted
        case EBADE = 52 // Invalid exchange
        case EBADR = 53 // Invalid request descriptor
        case EXFULL = 54 // Exchange full
        case ENOANO = 55 // No anode
        case EBADRQC = 56 // Invalid request code
        case EBADSLT = 57 // Invalid slot

        case EBFONT = 59 // Bad font file format
        case ENOSTR = 60 // Device not a stream
        case ENODATA = 61 // No data available
        case ETIME = 62 // Timer expired
        case ENOSR = 63 // Out of streams resources
        case ENONET = 64 // Machine is not on the network
        case ENOPKG = 65 // Package not installed
        case EREMOTE = 66 // Object is remote
        case ENOLINK = 67 // Link has been severed
        case EADV = 68 // Advertise error
        case ESRMNT = 69 // Srmount error
        case ECOMM = 70 // Communication error on send
        case EPROTO = 71 // Protocol error
        case EMULTIHOP = 72 // Multihop attempted
        case EDOTDOT = 73 // RFS specific error
        case EBADMSG = 74 // Not a data message
        case EOVERFLOW = 75 // Value too large for defined data type
        case ENOTUNIQ = 76 // Name not unique on network
        case EBADFD = 77 // File descriptor in bad state
        case EREMCHG = 78 // Remote address changed
        case ELIBACC = 79 // Can not access a needed shared library
        case ELIBBAD = 80 // Accessing a corrupted shared library
        case ELIBSCN = 81 // .lib section in a.out corrupted
        case ELIBMAX = 82 // Attempting to link in too many shared libraries
        case ELIBEXEC = 83 // Cannot exec a shared library directly
        case EILSEQ = 84 // Illegal byte sequence
        case ERESTART = 85 // Interrupted system call should be restarted
        case ESTRPIPE = 86 // Streams pipe error
        case EUSERS = 87 // Too many users
        case ENOTSOCK = 88 // Socket operation on non-socket
        case EDESTADDRREQ = 89 // Destination address required
        case EMSGSIZE = 90 // Message too long
        case EPROTOTYPE = 91 // Protocol wrong type for socket
        case ENOPROTOOPT = 92 // Protocol not available
        case EPROTONOSUPPORT = 93 // Protocol not supported
        case ESOCKTNOSUPPORT = 94 // Socket type not supported
        case EOPNOTSUPP = 95 // Operation not supported on transport endpoint
        case EPFNOSUPPORT = 96 // Protocol family not supported
        case EAFNOSUPPORT = 97 // Address family not supported by protocol
        case EADDRINUSE = 98 // Address already in use
        case EADDRNOTAVAIL = 99 // Cannot assign requested address
        case ENETDOWN = 100 // Network is down
        case ENETUNREACH = 101 // Network is unreachable
        case ENETRESET = 102 // Network dropped connection because of reset
        case ECONNABORTED = 103 // Software caused connection abort
        case ECONNRESET = 104 // Connection reset by peer
        case ENOBUFS = 105 // No buffer space available
        case EISCONN = 106 // Transport endpoint is already connected
        case ENOTCONN = 107 // Transport endpoint is not connected
        case ESHUTDOWN = 108 // Cannot send after transport endpoint shutdown
        case ETOOMANYREFS = 109 // Too many references: cannot splice
        case ETIMEDOUT = 110 // Connection timed out
        case ECONNREFUSED = 111 // Connection refused
        case EHOSTDOWN = 112 // Host is down
        case EHOSTUNREACH = 113 // No route to host
        case EALREADY = 114 // Operation already in progress
        case EINPROGRESS = 115 // Operation now in progress
        case ESTALE = 116 // Stale NFS file handle
        case EUCLEAN = 117 // Structure needs cleaning
        case ENOTNAM = 118 // Not a XENIX named type file
        case ENAVAIL = 119 // No XENIX semaphores available
        case EISNAM = 120 // Is a named type file
        case EREMOTEIO = 121 // Remote I/O error
        case EDQUOT = 122 // Quota exceeded

        case ENOMEDIUM = 123 // No medium found
        case EMEDIUMTYPE = 124 // Wrong medium type
        case ECANCELED = 125 // Operation Canceled
        case ENOKEY = 126 // Required key not available
        case EKEYEXPIRED = 127 // Key has expired
        case EKEYREVOKED = 128 // Key has been revoked
        case EKEYREJECTED = 129 // Key was rejected by service

        case EOWNERDEAD = 130 // Owner died
        case ENOTRECOVERABLE = 131 // State not recoverable
    }
}

func posix(_ block: @autoclosure () -> Int32, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) throws {
    guard block() == 0 else {
        print(errno)
        throw POSIXError(file: file, line: line, column: column, function: function)
    }
}

func getifaddrs() -> AnySequence<UnsafeMutablePointer<ifaddrs>> {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    try! posix(getifaddrs(&addrs))
    guard let first = addrs else { return AnySequence([]) }
    return AnySequence(sequence(first: first, next: { $0.pointee.ifa_next }))
}

func gethostname() throws -> String {
    var output = Data(count: 255)
    return try output.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<CChar>) -> String in
        try posix(gethostname(bytes, 255))
        return String(cString: bytes)
    }
}

