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
enum T {
  Integer
  String
  Object(
    Map[String, T],
    required~ : Array[String]?,
    additionalProperties~ : Bool
  )
  Array(T)
  Enum(Array[Json])
}

///|
pub fn integer() -> T {
  T::Integer
}

///|
pub fn string() -> T {
  T::String
}

///|
pub fn object(
  object : Map[String, T],
  additionalProperties~ : Bool = true,
  required? : Array[String]
) -> T {
  T::Object(object, required~, additionalProperties~)
}

///|
pub fn enums(values : Array[Json]) -> T {
  T::Enum(values)
}

///|
pub fn array(schema : T) -> T {
  T::Array(schema)
}

///|
pub fn T::to_json(self : T) -> Json {
  match self {
    T::Integer => { "type": "integer" }
    T::String => { "type": "string" }
    T::Enum(values) => { "enum": Json::array(values) }
    T::Array(schema) => {
      let result : Map[String, Json] = {
        "type": "array",
        "items": schema.to_json(),
      }
      Json::object(result)
    }
    T::Object(map, required~, additionalProperties~) => {
      let json_object = Map::new()
      for key, value in map {
        json_object[key] = value.to_json()
      }
      let result : Map[String, Json] = {
        "type": "object",
        "properties": Json::object(json_object),
      }
      if required is Some(required) {
        result["required"] = Json::array(required.map(Json::string))
      }
      if not(additionalProperties) {
        result["additionalProperties"] = false
      }
      Json::object(result)
    }
  }
}

///|
pub impl ToJson for T with to_json(self) {
  self.to_json()
}

///|
pub fn T::verify(self : T, json : Json) -> Bool {
  match (self, json) {
    (T::Integer, Number(n)) => n == n && n.to_int().to_double() == n
    (T::String, String(_)) => true
    (T::Enum(values), _) => values.contains(json)
    (T::Array(schema), Array(values)) => values.iter().all(schema.verify(_))
    (T::Object(map, required~, additionalProperties~), Object(json)) => {
      let required = @sorted_set.from_array(required.or([]))
      for key, value in map {
        if json.get(key) is Some(json) {
          if not(value.verify(json)) {
            return false
          }
        } else if required.contains(key) {
          return false
        }
      }
      for key, _ in json {
        if not(map.contains(key)) && not(additionalProperties) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
test "to_json" {
  @json.inspect(
    object({
      "name": object({
        "firstName": string(),
        "lastName": string(),
        "middleName": string(),
      }),
    }),
    content={
      "type": "object",
      "properties": {
        "name": {
          "type": "object",
          "properties": {
            "firstName": { "type": "string" },
            "lastName": { "type": "string" },
            "middleName": { "type": "string" },
          },
        },
      },
    },
  )
  @json.inspect(
    object({
      "name": object(
        { "firstName": string(), "lastName": string(), "middleName": string() },
        required=["firstName", "lastName"],
      ),
      "age": integer(),
    }),
    content={
      "type": "object",
      "properties": {
        "name": {
          "type": "object",
          "properties": {
            "firstName": { "type": "string" },
            "lastName": { "type": "string" },
            "middleName": { "type": "string" },
          },
          "required": ["firstName", "lastName"],
        },
        "age": { "type": "integer" },
      },
    },
  )
}

///|
test "verify" {
  let schema = object({
    "name": object({
      "firstName": string(),
      "lastName": string(),
      "middleName": string(),
    }),
  })
  assert_true(
    schema.verify({
      "name": { "firstName": "John", "lastName": "Doe", "middleName": "Smith" },
    }),
  )
  assert_false(
    schema.verify({ "name": { "firstName": "John", "lastName": 1 } }),
  )
  let schema = object({
    "name": object(
      { "firstName": string(), "lastName": string(), "middleName": string() },
      required=["firstName", "lastName"],
    ),
    "age": integer(),
  })
  assert_true(
    schema.verify({
      "name": { "firstName": "John", "lastName": "Doe" },
      "age": 30,
    }),
  )
  assert_false(schema.verify({ "name": { "firstName": "John" }, "age": 30 }))
}
