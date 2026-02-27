return {
    name = "NickIsADev/erlua",
    version = "3.2.8",
    description = "A scalable library with TTL data caching, classes, and ratelimit handling for the ERLC API v2.",
    license = "MIT",
    files = {
      "**.lua"
    },
    dependencies = {
        "creationix/coro-http",
        "luvit/json",
        "luvit/timer",
        "luvit/secure-socket"
    }
}
