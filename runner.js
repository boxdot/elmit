(function(){
    // worker with initial stdin port
    var worker = Elm.worker(Elm.Main, { stdIn: "" });

    // subscribe to stdout
    function logger(x) { console.log(x) }
    worker.ports.stdOut.subscribe(logger);

    // gather stdin in a string and forward to port
    var content = '';
    process.stdin.resume();
    process.stdin.on('data', function(buf) {
        content += buf.toString();
    });
    process.stdin.on('end', function() {
        worker.ports.stdIn.send(content);
    });
})();
