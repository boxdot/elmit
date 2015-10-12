Elm.Native.Parser = {};
Elm.Native.Parser = {};
Elm.Native.Parser.make = function(localRuntime) {

    localRuntime.Native = localRuntime.Native || {};
    localRuntime.Native.Parser = localRuntime.Parser.Native || {};

    var Result = Elm.Result.make(localRuntime);

    function parse(input) {
        try {
            return Result.Ok(JSON.stringify(parser.parse(input)));
        } catch (err) {
            return Result.Err(err.toString());
        }
    }

    return localRuntime.Native.Parser.values = {
        parse: parse
    };
};
