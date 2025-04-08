// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///| https://www.jsonrpc.org/specification
pub(all) enum Message {
  Request(id~ : Id, method_~ : String, params~ : Map[String, Json])
  Notification(method_~ : String, params~ : Map[String, Json])
  Response(id~ : Id, payload~ : Result[Map[String, Json], RPCError])
} derive(Eq, Show)

///|
pub impl @json.FromJson for Message with from_json(json, path) {
  match json {
    {
      "jsonrpc": "2.0",
      "method": String(method_),
      "params"? : None
      | Some(Object(_)) as params,
      "id": String(_)
      | Number(_) as id,
      ..
    } => {
      let id : Id = @json.from_json!(id, path=path.add_key("id"))
      Request(
        id~,
        method_~,
        params=params
          .map(fn {
            Object(params) => params
            _ => panic()
          })
          .or({}),
      )
    }
    {
      "jsonrpc": "2.0",
      "method": String(method_),
      "params"? : None
      | Some(Object(_)) as params,
      ..
    } =>
      Notification(
        method_~,
        params=params
          .map(fn {
            Object(params) => params
            _ => panic()
          })
          .or({}),
      )
    {
      "jsonrpc": "2.0",
      "id": String(_)
      | Number(_) as id,
      "result": Object(result),
      ..
    } => {
      let id = @json.from_json!(id, path=path.add_key("id"))
      Response(id~, payload=Ok(result))
    }
    { "jsonrpc": "2.0", "id": String(_) | Number(_) as id, "error": error, .. } => {
      let id = @json.from_json!(id, path=path.add_key("id"))
      Response(id~, payload=Err(@json.from_json!(error, path~)))
    }
    _ => raise @json.JsonDecodeError((path, "Invalid JSON RPC Message"))
  }
}

///|
pub impl ToJson for Message with to_json(self) {
  match self {
    Request(id~, method_~, params~) =>
      {
        "jsonrpc": "2.0",
        "method": String(method_),
        "id": id.to_json(),
        "params": Object(params),
      }
    Notification(method_~, params~) =>
      { "jsonrpc": "2.0", "method": String(method_), "params": Object(params) }
    Response(id~, payload=Ok(result)) =>
      { "jsonrpc": "2.0", "id": id.to_json(), "result": Object(result) }
    Response(id~, payload=Err(error)) =>
      { "jsonrpc": "2.0", "id": id.to_json(), "error": error.to_json() }
  }
}

///|
test {
  let message = Message::Request(id=Number(1), method_="test", params={ "a": 1 })
  @json.inspect!(message, content={
    "jsonrpc": "2.0",
    "method": "test",
    "id": Number(1),
    "params": { "a": 1 },
  })
  assert_eq!(
    @json.from_json?({
      "jsonrpc": "2.0",
      "method": "test",
      "id": 1,
      "params": { "a": 1 },
    }),
    Ok(message),
  )
}

///|
pub(all) struct RPCError {
  code : Int
  message : String
  data : Json?
} derive(Eq, Show, FromJson, ToJson)

///|
test {
  let rpc_error : RPCError = { code: 1000, message: "Error", data: None }
  @json.inspect!(rpc_error, content={ "code": 1000, "message": "Error" })
  let parsed : RPCError = rpc_error.to_json() |> @json.from_json!()
  assert_eq!(parsed, rpc_error)
  let rpc_error : RPCError = { code: 1000, message: "Error", data: Some(1) }
  @json.inspect!(rpc_error, content={
    "code": 1000,
    "message": "Error",
    "data": 1,
  })
  let parsed = rpc_error.to_json() |> @json.from_json!()
  assert_eq!(parsed, rpc_error)
}

///|
pub(all) enum Id {
  String(String)
  Number(Double)
} derive(Eq, Show, Hash)

///|
pub impl @json.FromJson for Id with from_json(json, path) {
  match json {
    String(s) => String(s)
    Number(n) => Number(n)
    _ => raise @json.JsonDecodeError((path, "Invalid id format"))
  }
}

///|
pub impl ToJson for Id with to_json(self) {
  match self {
    String(s) => String(s)
    Number(n) => Number(n)
  }
}
