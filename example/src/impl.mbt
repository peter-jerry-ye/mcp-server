///|
priv struct In {
  ev : @loop.T[@io.Pollable]
  stream : @streams.InputStream
  mut dropped : Bool
}

///|
impl @stream.Closable for In with close(self) {
  if not(self.dropped) {
    self.stream.drop()
    self.dropped = true
  }
}

///|
impl @stream.Closable for In with closed(self) {
  self.dropped || self.stream.read(0) == Err(Closed)
}

///|
impl @stream.InputStream for In with read(self, len) {
  read_in(self, len)
}

///|
fn read_in(in_ : In, len : UInt64) -> @promise.T[Bytes] {
  @promise.spawn(async fn(_defer) {
    in_.ev.sync!!(in_.stream.subscribe())
    let bytes = in_.stream.read(len).unwrap_or_error!()
    Bytes::from_fixedarray(bytes)
  })
}

///|
impl @stream.InputStream for In with readable(self) {
  not(self.dropped) && self.stream.read(0) is Ok(_)
}

///|
priv struct Out {
  ev : @loop.T[@io.Pollable]
  stream : @streams.OutputStream
  mut dropped : Bool
}

///|
impl @stream.Closable for Out with close(self) {
  if not(self.dropped) {
    self.stream.drop()
    self.dropped = true
  }
}

///|
impl @stream.Closable for Out with closed(self) {
  self.dropped || self.stream.check_write() == Err(Closed)
}

///|
impl @stream.OutputStream for Out with write(self, bytes) {
  write_out(self, bytes)
}

///|
fn write_out(out : Out, bytes : Bytes) -> @promise.T[Unit] {
  @promise.spawn(async fn(_defer) {
    out.ev.sync!!(out.stream.subscribe())
    out.stream.write(bytes.to_fixedarray()).unwrap_or_error!()
  })
}

///|
impl @stream.OutputStream for Out with writable(self) {
  not(self.dropped) && self.stream.check_write() is Ok(_)
}

///|
let stdin : &@stream.InputStream = (
    { ev: @io.event_loop, stream: @io.stdin, dropped: false } : In)
  as &@stream.InputStream

///|
let stdout : &@stream.OutputStream = (
    { ev: @io.event_loop, stream: @io.stdout, dropped: false } : Out)
  as &@stream.OutputStream

///|
let stderr : &@stream.OutputStream = (
    { ev: @io.event_loop, stream: @io.stderr, dropped: false } : Out)
  as &@stream.OutputStream
