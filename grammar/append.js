Elm.Native.Parser = {};
Elm.Native.Parser = {};
Elm.Native.Parser.make = function(localRuntime) {

    localRuntime.Native = localRuntime.Native || {};
    localRuntime.Native.Parser = localRuntime.Parser.Native || {};

    var Result = Elm.Result.make(localRuntime);

    function parse(input) {
        try {
            var parsed = JSON.stringify(parser.parse(input), 0, 2);
            console.log(parsed);
            return Result.Ok(parsed);
        } catch (err) {
            return Result.Err(err.toString());
        }
    }

    return localRuntime.Native.Parser.values = {
        parse: parse
    };
};
