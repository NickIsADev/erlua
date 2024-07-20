  return {
    name = "NickIsADev/erlua",
    version = "0.0.6",
    description = "A library providing dynamic ratelimiting, custom functions, and easy access to the ER:LC API.",
    license = "MIT",
    files = {
      "*.lua"
    },
    dependencies = {
        "creationix/coro-http",
	"luvit/json",
	"luvit/secure-socket"
    }
  }
  
