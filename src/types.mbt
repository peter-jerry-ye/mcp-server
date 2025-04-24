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

///|
typealias Schema = @schema.T

///|
typealias Message = @rpc.Message

///|
typealias Id = @rpc.Id

///|
typealias RPCError = @rpc.RPCError

///|
/// RFC 5424
pub(all) enum LogLevel {
  Debug
  Info
  Notice
  Warning
  Error
  Critical
  Alert
  Emergency
} derive(Eq, Show, Compare)

test "loglevel" {
  assert_true!(Debug < Info)
  assert_true!(Info < Warning)
  assert_true!(Warning < Error)
  assert_true!(Error < Critical)
  assert_true!(Critical < Alert)
  assert_true!(Alert < Emergency)
}

///|
priv struct Tool {
  description : String
  inputSchema : Schema
  cb : async (Json, Server) -> Response
}

///|
priv struct Prompt {
  description : String
  arguments : Array[PromptArgument]
  cb : (Map[String, Json]) -> Array[PromptMessage]
}

///|
pub(all) enum Role {
  User
  Assistant
}

///|
pub(all) struct PromptMessage {
  role : Role
  message : Content
}

///|
struct PromptArgument {
  name : String
  description : String?
  required : Bool?
}

///|
pub fn prompt_argument(
  name : String,
  description? : String,
  required? : Bool
) -> PromptArgument {
  { name, description, required }
}

///|
pub(all) enum Content {
  Text(text~ : String)
  Image(data~ : String, mimeType~ : String)
  Resource(uri~ : String, mimeType~ : String, text~ : String)
}

///|
pub(all) struct Response {
  isError : Bool
  payload : Array[Content]
}

///|
pub struct Root {
  uri : String
  name : String?
} derive(Eq, Show)
