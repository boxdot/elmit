Elm.Native.Parser = {};
Elm.Native.Parser.make = function(localRuntime) {

    localRuntime.Native = localRuntime.Native || {};
    localRuntime.Native.Parser = localRuntime.Parser.Native || {};

    var Result = Elm.Result.make(localRuntime);
    var Maybe = Elm.Maybe.make(localRuntime);
    var List = Elm.Native.List.make(localRuntime);
    var Types = Elm.Types.make(localRuntime);

    var Debug = Elm.Debug.make(localRuntime);


    parser.yy = {
        List: List.fromArray,
        Cons: List.cons.func,
        Nil: List.Nil,
        Nothing: Maybe.Nothing,
        Just: Maybe.Just,
        Tag: function() {
            return Types.Tag(Types.TagRecord.func.apply(this, arguments));
        },
        Attr: Types.Attribute.func,
        Comment: Types.Comment,
        Text: Types.Text,
        Debug: function(x) { Debug.log.func("debug", x); }
    };

    function parse(input) {
        try {
            var parsed = parser.parse(input);
            Debug.log.func("parsed", parsed);
            return Result.Ok(parsed);
        } catch (err) {
            return Result.Err(err.toString());
        }
    }

    return localRuntime.Native.Parser.values = {
        parse: parse
    };
};
