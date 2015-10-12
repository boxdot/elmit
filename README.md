_Work in progress!_

# Elmit

A simple converter from to Html (with a Handlebars flavour) to Elm.

## Build

```(bash)
make init
make
```

This will install dependencies (`jison` and `elm-console`), compile the parser and build `elmit.js` in the `build` directory.

## Usage

```(bash)
$ cat<<EOF | node build/elmit.js
<div class="main">
    <h1>Hello</h1>
    <p class="body">
        lorem ipsum
    </p>
</div>
EOF
```

Output
```(elm)
-- compiled from html
module ToDo where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


view =
  [ div
    [ class "main"
    ]
    [ h1 []
      [ text "Hello"
      ]
    , p
      [ class "body"
      ]
      [ text "lorem ipsum"
      ]
    ]
  ]

```
