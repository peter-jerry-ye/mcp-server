///|
struct Stream {
  stream : @uv.Stream
  mut closed : Bool
}

///|
fn stream(stream : @uv.Stream) -> Stream {
  { stream, closed: false }
}

///|
impl @stream.Closable for Stream with closed(self) {
  self.closed ||
  (
    self.stream.is_closing() &&
    {
      self.closed = true
      true
    }
  )
}

///|
impl @stream.Closable for Stream with close(self) {
  self.stream.close(ignore)
  self.closed = true
}

///|
impl @stream.InputStream for Stream with readable(self) {
  not(self.closed()) && self.stream.is_readable()
}

///|
impl @stream.InputStream for Stream with read(self, len) {
  @promise.spawn(fn(_defer) { read_stream!(self.stream, len) })
}

///|
async fn read_stream(stream : @uv.Stream, len : UInt64) -> Bytes! {
  let buffer = Bytes::make(len.to_int(), b'\x00')
  shift!(fn(resolve, reject) {
    try {
      stream.read_start!(
        fn(_stream, _len) { buffer[:] },
        fn(_stream, _nread, buf) {
          stream.read_stop?() |> ignore
          resolve([..buf])
        },
        fn(_stream, err) {
          stream.read_stop?() |> ignore
          reject(err)
        },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
async fn shift[A](f : ((A) -> Unit, (Error) -> Unit) -> Unit) -> A! = "%async.suspend"

///|
impl @stream.OutputStream for Stream with writable(self) {
  not(self.closed()) && self.stream.is_writable()
}

///|
impl @stream.OutputStream for Stream with write(self, bytes) {
  @promise.spawn(fn(_defer) { write_stream!(self.stream, bytes) })
}

///|
impl @stream.Flushable for Stream with flush(_self) {
  @promise.resolve(())
}

///|
async fn write_stream(stream : @uv.Stream, bytes : Bytes) -> Unit! {
  shift!(fn(resolve, reject) {
    try {
      stream.write!([bytes[:]], fn(_write) { resolve(()) }, fn(_stream, err) {
        reject(err)
      })
    } catch {
      e => reject(e)
    }
  })
}

///|
struct File {
  file : @uv.File
  uv : @uv.Loop
}

///|
fn file(file : @uv.File, uv : @uv.Loop) -> File {
  { file, uv }
}

///|
impl @stream.Closable for File with close(_self) {

}

///|
impl @stream.Closable for File with closed(_self) {
  // TODO
  false
}

///|
impl @stream.OutputStream for File with writable(self) {
  not(self.closed())
}

///|
impl @stream.OutputStream for File with write(self, bytes) {
  @promise.spawn(fn(_defer) { write_file!(self, bytes) })
}

///|
impl @stream.Flushable for File with flush(_self) {
  // TODO: fsync
  @promise.resolve(())
}

///|
impl @stream.InputStream for File with readable(self) {
  not(self.closed())
}

///|
impl @stream.InputStream for File with read(self, len) {
  @promise.spawn(fn(_defer) { read_file!(self, len) })
}

///|
async fn read_file(file : File, len : UInt64) -> Bytes! {
  let buffer = Bytes::make(len.to_int(), b'\x00')
  shift!(fn(resolve, reject) {
    try {
      file.uv.fs_read!(
        file.file,
        [buffer[:]],
        fn(_fs, nlen) { resolve([..buffer[:nlen]]) },
        fn(_fs, error) { reject(error) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
async fn write_file(file : File, bytes : Bytes) -> Unit! {
  shift!(fn(resolve, reject) {
    try {
      file.uv.fs_write!(
        file.file,
        [bytes[:]],
        fn(_write, _len) { resolve(()) },
        fn(_file, err) { reject(err) },
      )
    } catch {
      e => reject(e)
    }
  })
}

///|
async fn random(uv : @uv.Loop, len : UInt64) -> Bytes! {
  let buffer = Bytes::make(len.to_int(), b'\x00')
  shift!(fn(resolve, reject) {
    try {
      uv.random!(buffer[:], 0, fn(_random, _buffer) { resolve(buffer) }, fn(
        _random,
        err
      ) {
        reject(err)
      })
    } catch {
      e => reject(e)
    }
  })
}
