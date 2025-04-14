///|
struct Stream {
  stream : @uv.Stream
  mut closed : Bool
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
}

///|
impl @stream.InputStream for Stream with readable(self) {
  not(self.closed())
}

///|
impl @stream.InputStream for Stream with read(self, len) {
  @promise.spawn(fn(_defer) { read_stream!!(self.stream, len) })
}

///|
async fn read_stream(stream : @uv.Stream, len : UInt64) -> Bytes! {
  let buffer = Bytes::make(len.to_int(), b'\x00')
  let mut start = 0
  shift!!(fn(resolve, reject) {
    try {
      stream.read_start!(
        fn(_stream, _len) { buffer[start:] },
        fn(_stream, nread, _buf) {
          start += nread
          if start == len.to_int() {
            stream.read_stop?() |> ignore
            resolve(())
          }
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
  buffer
}

///|
async fn shift[A](f : ((A) -> Unit, (Error) -> Unit) -> Unit) -> A! = "%async.suspend"

///|
impl @stream.OutputStream for Stream with writable(self) {
  not(self.closed())
}

///|
impl @stream.OutputStream for Stream with write(self, bytes) {
  @promise.spawn(fn(_defer) { write_stream!!(self.stream, bytes) })
}

///|
async fn write_stream(stream : @uv.Stream, bytes : Bytes) -> Unit! {
  shift!!(fn(resolve, reject) {
    try {
      stream.write!([bytes[:]], fn(_write) { resolve(()) }, fn(_stream, err) {
        reject(err)
      })
    } catch {
      e => reject(e)
    }
  })
}
